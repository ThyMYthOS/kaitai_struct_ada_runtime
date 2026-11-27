package io.kaitai.struct.testtranslator.specgenerators

import java.nio.ByteBuffer
import java.nio.charset.{Charset, CodingErrorAction}

import io.kaitai.struct.RuntimeConfig
import io.kaitai.struct.AdaClassCompiler
import io.kaitai.struct.ClassTypeProvider
import io.kaitai.struct.datatype.DataType._
import io.kaitai.struct.datatype._
import io.kaitai.struct.exprlang.Ast
import io.kaitai.struct.format._
import io.kaitai.struct.testtranslator.{Main, TestAssert, TestEquals, TestException, TestSpec}
import io.kaitai.struct.translators.{AdaTranslator, AdaUnsupported, VEnum, VInt, VU64Lit}

import scala.collection.mutable
import scala.collection.mutable.ListBuffer

/** The test cannot be expressed against the Ada API; the message is the reason that goes into the report. */
class AdaNotTranslated(msg: String) extends RuntimeException(msg)

/**
  * Test spec generator for Ada. For a test it writes one main procedure
  * `test_<name>.adb` that reads the data file, parses it with the generated
  * parser and prints `ok <n>` or `FAIL <n>: <expression>` for every assert,
  * then `PASSED` or `FAILED`.
  *
  * Parsed values are read through the accessors of the generated package,
  * which have preconditions. Every condition under which an access is
  * defined (`Valid`, `Has_X`, `X_Case`, an index below `X_Count`, the outcome
  * of an instance, ...) is checked before the access, so that an assert
  * whose value does not exist is reported as FAIL and never raises.
  *
  * The names of the generated code come from [[AdaClassCompiler]] itself
  * (`memberName`, `memberBase`, `presenceName`, `isStored`, ...); the
  * literals of expected values are translated by [[AdaTranslator]].
  *
  * If a test cannot be translated, the output is a single comment line that
  * starts with `--  NOT TRANSLATED:` and names the reason.
  */
class AdaSG(spec: TestSpec, provider: ClassTypeProvider) extends SpecGenerator {
  import AdaSG._

  private val top: ClassSpec = provider.allClasses.firstSpec
  private val cc = new AdaClassCompiler(provider.allClasses, top, RuntimeConfig())
  private val tr = new AdaTranslator(provider, cc)
  private lazy val topPkg = pkgOf(top)

  override def indentStr: String = "   "
  override def fileName(name: String): String = s"test_$name.adb"

  private var text: String = ""
  override def results: String = text

  // ------------------------------------------------------------------ names

  private def base(raw: String): String = cc.base(raw)

  /** Packages of descriptions that the program uses: they need a `with` */
  private val withPkgs = mutable.LinkedHashSet[String]()

  private def pkgOf(cs: ClassSpec): String = {
    withPkgs += base(cs.name.head)
    cc.fullPackageOf(cs)
  }

  private def pkgOfNames(names: List[String]): String = {
    withPkgs += base(names.head)
    (base(names.head) +: names.tail.map(n => base(n) + "_Type")).mkString(".")
  }

  private def nt(msg: String): Nothing = throw new AdaNotTranslated(msg)

  private val KT = "Kaitai.Types."

  // ---------------------------------------------------------------- values

  /** The value of an expression in terms of Ada code. All values are defined where the guards of their context hold. */
  private sealed trait AV
  /** An integer: Ada expression, name of its Ada type in Kaitai.Types, enumeration it belongs to */
  private case class AInt(code: String, ada: String, enum: Option[EnumSpec]) extends AV
  private case class ABool(code: String) extends AV
  /** A float: Ada expression of the raw bits and the width in bytes */
  private case class AFloat(bits: String, width: Int) extends AV
  /** A float that an instance computes: Ada expression of an F64 */
  private case class AF64(code: String) extends AV
  /** Bytes and strings are slices of `buf`, the array that the value refers to: the input, or the array of a processed field */
  private case class ABytes(code: String, buf: String) extends AV
  private case class AStr(code: String, enc: String, buf: String) extends AV
  private case class AUser(cs: ClassSpec, code: String, buf: String) extends AV
  /** A repeated member */
  private case class AArr(cs: ClassSpec, obj: String, a: AttrLikeSpec, buf: String) extends AV
  /** A member whose type depends on a value */
  private case class ASwitch(cs: ClassSpec, obj: String, a: AttrSpec, st: SwitchType, buf: String) extends AV
  /** The stream the root was parsed from */
  private case class AIo(code: String) extends AV
  /** A member of a value of an opaque type, read with the accessor that the hand-written package is assumed to have; its type is not known */
  private case class AOpaque(code: String) extends AV
  /** An integer that the expression turns into its decimal string */
  private case class AIntStr(i: AInt) extends AV
  /** Condition that tells a member is absent, for `expected: null` */
  private case class AAbsent(cond: String) extends AV

  private case class Step(guards: List[String], decls: List[String], stmts: List[String], cleanup: List[String])

  /** What the evaluation of an expression collects: the steps that fetch values, and the conditions still to be checked */
  private class Ctx {
    val steps = ListBuffer[Step]()
    val guards = ListBuffer[String]()
    private var fresh = 0
    def need(g: String): Unit = if (!guards.contains(g)) guards += g
    def name(prefix: String): String = { fresh += 1; s"$prefix$fresh" }
    /** A step that has to run after what has been checked so far */
    def step(decls: List[String], stmts: List[String], cleanup: List[String] = Nil): Unit = {
      steps += Step(guards.toList, decls, stmts, cleanup)
      guards.clear()
    }
  }

  private val useTypes = mutable.LinkedHashSet[String]()
  private val usedLibs = mutable.LinkedHashSet[String]()
  private var counter = 0
  private def freshGlobal(prefix: String): String = { counter += 1; s"$prefix$counter" }

  private def useType(t: String): Unit = useTypes += t

  // --------------------------------------------------------------- members

  private def findMember(cs: ClassSpec, name: String): MemberSpec = {
    if (!name.matches("[a-z][a-z0-9_]*") && !name.matches("_unnamed[0-9]+"))
      nt(s"`$name` of a value: parsed values keep no references to their parent, root or stream")
    cs.seq.find(a => a.id.humanReadable == name || a.id == NamedIdentifier(name))
      .orElse(cs.params.find(_.id == NamedIdentifier(name)))
      .orElse(cs.instances.get(InstanceIdentifier(name)))
      .getOrElse(nt(s"no member `$name` in type ${cs.nameAsStr}"))
  }

  private def adaInt(dt: DataType): String = dt match {
    case CalcIntType => "S64"
    case _ => AdaTranslator.intInfo(dt).map(_._1).getOrElse(nt(s"integer type $dt"))
  }

  /** The value of Ada expression `code` that was read as `dt` (floats: the code gives the raw bits). */
  private def valueOf(dt: DataType, code: String, buf: String): AV = dt match {
    case et: EnumType => AInt(code, adaInt(et.basedOn), et.enumSpec)
    case _: IntType => AInt(code, adaInt(dt), None)
    case _: BooleanType => ABool(code)
    case FloatMultiType(w, _) => AFloat(code, w.width)
    case CalcFloatType => AF64(code)
    case _: BytesType => ABytes(code, buf)
    case StrFromBytesType(_, enc, _) => AStr(code, enc, buf)
    case ut: UserType => AUser(ut.classSpec.get, code, buf)
    case other => nt(s"value of type $other")
  }

  /** Type of what the accessor of a stored value returns, as in `storedType` of the class compiler */
  private def storedAda(dt: DataType): String = dt match {
    case et: EnumType => KT + adaInt(et.basedOn)
    case _: IntType => KT + adaInt(dt)
    case _: BooleanType => "Boolean"
    case FloatMultiType(w, _) => if (w.width == 4) KT + "U32" else KT + "U64"
    case _: BytesType | _: StrType => KT + "Slice"
    case ut: UserType => pkgOf(ut.classSpec.get) + ".T"
    case other => nt(s"type $other")
  }

  /**
    * Accessor of a member of `cs`, whose record is `obj`. With `absent`, the
    * condition that the member does not exist is returned instead.
    */
  private def member(ctx: Ctx, cs: ClassSpec, obj: String, name: String, buf: String, absent: Boolean = false): AV = {
    val pkg = pkgOf(cs)
    val m = findMember(cs, name)
    val nm = cc.memberName(cs, m.id)
    val bs = cc.memberBase(m.id)
    val has = s"$pkg.${cc.presenceName(cs, m.id)}"
    def presence(cond: Boolean, args: String): AV = {
      if (absent) {
        if (!cond) nt(s"`$name` is not optional, so `null` cannot be its value")
        AAbsent(s"not $has ($args)")
      } else {
        if (cond) ctx.need(s"$has ($args)")
        null
      }
    }
    m match {
      case a: AttrSpec =>
        if (!cc.isStored(a)) nt(s"field `$name` holds `contents`, which is checked but not stored")
        a.dataType match {
          case st: SwitchType if absent && a.cond.repeat == NoRepeat =>
            // no case of the switch matched, or the field is not there
            val intSwitch = st.cases.values.forall(isIntCase)
            val parts = ListBuffer[String]()
            if (a.cond.ifExpr.isDefined || (intSwitch && !st.hasElseCase)) parts += s"not $has ($obj)"
            if (!intSwitch) {
              useType(s"$pkg.${bs}_Kind")
              parts += s"$pkg.${bs}_Case ($obj) = $pkg.${bs}_Is_None"
            }
            if (parts.isEmpty) nt(s"switch `$name` has an else case, so `null` cannot be its value")
            return AAbsent(parts.mkString(" or else "))
          case _ =>
        }
        val r = presence(a.cond.ifExpr.isDefined, obj)
        if (r != null) return r
        if (a.cond.repeat != NoRepeat) {
          if (AdaTranslator.hasProcess(a.dataType)) nt(s"`$name` is a repeated field with `process`")
          AArr(cs, obj, a, buf)
        } else a.dataType match {
          case st: SwitchType => switchOf(ctx, cs, obj, a, st, buf)
          case dt if AdaTranslator.hasProcess(dt) => processed(ctx, cs, obj, a, dt, buf)
          case ut: UserType if ut.classSpec.exists(_ eq cs) =>
            // a field of the type itself is parsed again when asked for
            val l = ctx.name("L")
            val o = ctx.name("Outcome")
            ctx.step(List(s"$l : ${pkg}.T;", s"$o : ${KT}Status_Kind;"), List(s"$pkg.$nm ($obj, $buf, $l, $o);"))
            useType(KT + "Status_Kind")
            ctx.need(s"$o = ${KT}Success")
            ctx.need(s"$pkg.Valid ($l)")
            AUser(cs, l, buf)
          case dt => scalar(pkg, nm, bs, dt, obj, buf)
        }
      case p: ParamDefSpec =>
        scalar(pkg, nm, bs, p.dataType, obj, buf)
      case v: ValueInstanceSpec =>
        val usesBuf = cc.valueInstanceUsesBuffer(cs, v)
        val args = if (usesBuf) s"$obj, $buf" else obj
        val r = presence(cc.valueInstanceHasGuard(cs, v), args)
        if (r != null) return r
        v.dataType match {
          case et: EnumType => AInt(s"$pkg.${bs}_Value ($args)", "S64", et.enumSpec)
          case _: IntType => AInt(s"$pkg.$nm ($args)", if (cc.valueInstanceIsU64(cs, v)) "U64" else "S64", None)
          case _: BooleanType => ABool(s"$pkg.$nm ($args)")
          case _: FloatType => AF64(s"$pkg.$nm ($args)")
          case _: BytesType => ABytes(s"$pkg.$nm ($args)", buf)
          case _: StrType => AStr(s"$pkg.$nm ($args)", instanceEncoding(cs, v), buf)
          case other => nt(s"value instance of type $other")
        }
      case p: ParseInstanceSpec =>
        val r = presence(p.cond.ifExpr.isDefined, obj)
        if (r != null) return r
        val l = ctx.name("L")
        val o = ctx.name("Outcome")
        ctx.step(
          List(s"$l : ${storedAda(p.dataType)};", s"$o : ${KT}Status_Kind;"),
          List(s"$pkg.$nm ($obj, $buf, $l, $o);")
        )
        useType(KT + "Status_Kind")
        ctx.need(s"$o = ${KT}Success")
        val v = valueOf(p.dataType, l, buf)
        v match {
          case AUser(c, code, _) => ctx.need(s"${pkgOf(c)}.Valid ($code)")
          case _ =>
        }
        v
    }
  }

  /**
    * A field with `process`: the accessor is a procedure that undoes the processing into an array of the
    * caller. The array is on the heap, as large as the input for xor and rotate, generously larger for zlib.
    * What is read from a processed field of a type refers to that array.
    */
  private def processed(ctx: Ctx, cs: ClassSpec, obj: String, a: AttrSpec, dt: DataType, buf: String): AV = {
    val pkg = pkgOf(cs)
    val nm = cc.memberName(cs, a.id)
    // the result of zlib is larger than the input, and a custom process may do what it likes
    val zlib = dt match {
      case b: BytesType => b.process.exists(p => p == ProcessZlib || p.isInstanceOf[ProcessCustom])
      case ut: UserTypeFromBytes => ut.process.exists(p => p == ProcessZlib || p.isInstanceOf[ProcessCustom])
      case _ => false
    }
    val work = ctx.name("Work")
    val o = ctx.name("Outcome")
    val size = if (zlib) s"$buf'Length * 256 + 4096" else s"$buf'Length + 1"
    useType(KT + "Status_Kind")
    val decls = List(s"$work : Buffer_Access := new ${KT}Bytes (1 .. $size);", s"$o : ${KT}Status_Kind;")
    val cleanup = List(s"Free ($work);")
    dt match {
      case _: BytesType =>
        val last = ctx.name("Last")
        val sl = ctx.name("Item")
        ctx.step(decls ++ List(s"$last : ${KT}Length;", s"$sl : ${KT}Slice;"),
          List(s"$pkg.$nm ($obj, $buf, $work.all, $last, $o);", s"$sl := (First => $work.all'First, Last => $last);"), cleanup)
        ctx.need(s"$o = ${KT}Success")
        ABytes(sl, s"$work.all")
      case ut: UserTypeFromBytes =>
        val l = ctx.name("L")
        ctx.step(decls ++ List(s"$l : ${pkgOf(ut.classSpec.get)}.T;"), List(s"$pkg.$nm ($obj, $buf, $work.all, $l, $o);"), cleanup)
        ctx.need(s"$o = ${KT}Success")
        ctx.need(s"${pkgOf(ut.classSpec.get)}.Valid ($l)")
        AUser(ut.classSpec.get, l, s"$work.all")
      case other => nt(s"process on $other")
    }
  }

  /** The encoding of a string that a value instance holds, if its expression is a field */
  private def instanceEncoding(cs: ClassSpec, v: ValueInstanceSpec): String = {
    val saved = provider.nowClass
    provider.nowClass = cs
    try {
      tr.translate(v.value).vt match {
        case io.kaitai.struct.translators.VStr(enc) => enc
        case _ => "UTF-8"
      }
    } catch { case _: Throwable => "UTF-8" }
    finally provider.nowClass = saved
  }

  private def scalar(pkg: String, nm: String, bs: String, dt: DataType, obj: String, buf: String): AV = dt match {
    case _: EnumType => valueOf(dt, s"$pkg.${bs}_Value ($obj)", buf)
    case _: FloatMultiType => valueOf(dt, s"$pkg.${bs}_Bits ($obj)", buf)
    case _ => valueOf(dt, s"$pkg.$nm ($obj)", buf)
  }

  // switch: the cases of the switch with their variant names, as the class compiler names them
  private def isIntCase(dt: DataType): Boolean = dt match {
    case _: IntType | _: EnumType => true
    case _ => false
  }

  private def variants(st: SwitchType): List[(DataType, String)] =
    try cc.switchVariants(st) catch { case u: AdaUnsupported => nt(u.getMessage) }

  private def switchOf(ctx: Ctx, cs: ClassSpec, obj: String, a: AttrSpec, st: SwitchType, buf: String): AV = {
    val pkg = pkgOf(cs)
    if (st.cases.values.forall(isIntCase)) {
      val ada = try cc.switchIntType(st) catch { case u: AdaUnsupported => nt(u.getMessage) }
      if (a.cond.ifExpr.isEmpty && !st.hasElseCase)
        ctx.need(s"$pkg.${cc.presenceName(cs, a.id)} ($obj)")
      AInt(s"$pkg.${cc.memberName(cs, a.id)} ($obj)", ada, None)
    } else ASwitch(cs, obj, a, st, buf)
  }

  private def castTo(ctx: Ctx, v: AV, t: Ast.typeId): AV = v match {
    case ASwitch(cs, obj, a, st, buf) =>
      val pkg = pkgOf(cs)
      val bs = cc.memberBase(a.id)
      val vs = variants(st)
      val wanted: List[(DataType, String)] =
        if (t.names == Seq("bytes")) vs.filter(_._1.isInstanceOf[BytesType])
        else if (t.names == Seq("str")) vs.filter(_._1.isInstanceOf[StrType])
        else {
          val target = resolveType(t)
          vs.filter { case (dt, _) => dt match { case ut: UserType => ut.classSpec.exists(_ eq target); case _ => false } }
        }
      wanted match {
        case List((dt, n)) =>
          ctx.need(s"$pkg.${bs}_Case ($obj) = $pkg.${bs}_Is_$n")
          useType(s"$pkg.${bs}_Kind")
          val code = s"$pkg.${bs}_As_$n ($obj)"
          dt match {
            case ut: UserType => ctx.need(s"${pkgOf(ut.classSpec.get)}.Valid ($code)"); AUser(ut.classSpec.get, code, buf)
            case _: BytesType => ABytes(code, buf)
            case _ => AStr(code, "UTF-8", buf)
          }
        case Nil => nt(s"cast to ${t.nameAsStr}: no such case in the switch")
        case _ => nt(s"cast to ${t.nameAsStr}: the switch has several cases of that type")
      }
    case AOpaque(code) =>
      // `.as<u1>`: the test says what the type of the member is
      t.names.toList match {
        case List(n) if n.matches("[us][1248](le|be)?") =>
          AInt(code, (if (n.head == 'u') "U" else "S") + (n.drop(1).take(1).toInt * 8), None)
        case _ => nt(s"cast `.as<${t.nameAsStr}>` of a member of an opaque type")
      }
    case AUser(cs, _, _) if t.names.nonEmpty && resolveType(t).eq(cs) => v
    case _ => nt(s"cast `.as<${t.nameAsStr}>` of something that is not a switch")
  }

  private def resolveType(t: Ast.typeId): ClassSpec = {
    val ns = t.names.toList
    def suffix(c: ClassSpec): Int = c.name.reverse.zip(ns.reverse).takeWhile(x => x._1 == x._2).size
    // the path as written may name a type through a sibling (`a::chunk::chunk_body::x` for `a::chunk_body::x`)
    def byName: ClassSpec = {
      val all = ListBuffer[ClassSpec]()
      provider.allClasses.forEachRec(c => all += c)
      val cands = all.filter(_.name.last == ns.last).toList
      val best = if (cands.isEmpty) 0 else cands.map(suffix).max
      cands.filter(suffix(_) == best) match {
        case List(c) => c
        case _ => nt(s"unknown type ${t.nameAsStr}")
      }
    }
    provider.allClasses.get(ns.head) match {
      case Some(c0) =>
        try ns.tail.foldLeft(c0)((c, n) => c.types.getOrElse(n, throw new NoSuchElementException(n)))
        catch { case _: NoSuchElementException => byName }
      case None =>
        val saved = provider.nowClass
        provider.nowClass = top
        try provider.resolveClassSpec(t) catch { case _: Throwable => nt(s"unknown type ${t.nameAsStr}") }
        finally provider.nowClass = saved
    }
  }

  // ------------------------------------------------------------ evaluation

  private val RootName = Main.INIT_OBJ_NAME

  private def index(ctx: Ctx, e: Ast.expr): String = e match {
    case Ast.expr.IntNum(n) if n >= 0 => n.toString
    case Ast.expr.IntNum(n) => nt(s"negative index $n")
    case _ => nt("index that is not a constant")
  }

  private def eval(ctx: Ctx, e: Ast.expr, absent: Boolean = false): AV = e match {
    case Ast.expr.Name(Ast.identifier(RootName)) =>
      AUser(top, "R", "Buffer.all")
    case Ast.expr.Attribute(Ast.expr.Name(Ast.identifier(RootName)), Ast.identifier(Identifier.IO)) =>
      AIo("S")
    case Ast.expr.Attribute(v, Ast.identifier(attr)) =>
      val last = absent
      if (last) {
        eval(ctx, v) match {
          case AUser(cs, obj, buf) => member(ctx, cs, obj, attr, buf, absent = true)
          case _ => nt("`null` expected for something that is not a member")
        }
      } else attribute(ctx, eval(ctx, v), attr)
    case Ast.expr.Subscript(v, i) =>
      eval(ctx, v) match {
        case AArr(cs, obj, a, buf) => element(ctx, cs, obj, a, index(ctx, i), buf)
        case ABytes(code, buf) =>
          val ix = index(ctx, i)
          ctx.need(s"$ix < ${KT}Size ($code)")
          useType(KT + "Length")
          AInt(s"$buf ($code.First + $ix)", "U8", None)
        case _ => nt("subscript of something that is not an array")
      }
    case Ast.expr.CastToType(v, t) =>
      castTo(ctx, eval(ctx, v), t)
    case Ast.expr.Call(Ast.expr.Attribute(v, Ast.identifier("to_s")), Seq()) =>
      eval(ctx, v) match {
        case i: AInt => AIntStr(i)
        case _ => nt("`to_s` of something that is not an integer")
      }
    case other => nt(s"expression `${src(other)}` in an assert")
  }

  private def attribute(ctx: Ctx, v: AV, attr: String): AV = v match {
    case AUser(cs, obj, _) if cs.meta.isOpaque =>
      // the type is written by hand, and the description does not say what its members are: the accessor has the name
      // that a generated one would have
      AOpaque(s"${pkgOf(cs)}.${cc.base(attr)} ($obj)")
    case AUser(cs, obj, buf) => member(ctx, cs, obj, attr, buf)
    case ASwitch(cs, obj, a, st, buf) if variants(st).size == 1 && variants(st).head._1.isInstanceOf[UserType] =>
      // a switch with one type of case: the member is that of the only variant, where the switch chose it
      val pkg = pkgOf(cs)
      val bs = cc.memberBase(a.id)
      val (dt, n) = variants(st).head
      ctx.need(s"$pkg.${bs}_Case ($obj) = $pkg.${bs}_Is_$n")
      useType(s"$pkg.${bs}_Kind")
      val code = s"$pkg.${bs}_As_$n ($obj)"
      val ut = dt.asInstanceOf[UserType]
      ctx.need(s"${pkgOf(ut.classSpec.get)}.Valid ($code)")
      member(ctx, ut.classSpec.get, code, attr, buf)
    case AIo(s) =>
      attr match {
        case "pos" => usedLibs += "Streams"; AInt(s"Kaitai.Streams.Pos ($s)", "Length", None)
        case "size" => usedLibs += "Streams"; AInt(s"Kaitai.Streams.Size ($s)", "Length", None)
        case "eof" => usedLibs += "Streams"; ABool(s"Kaitai.Streams.Is_EOF ($s)")
        case _ => nt(s"`_io.$attr`")
      }
    case AArr(cs, obj, a, _) =>
      attr match {
        case "size" =>
          val bs = cc.memberBase(a.id)
          AInt(s"${pkgOf(cs)}.${bs}_Count ($obj)", "Length", None)
        case _ => nt(s"`.$attr` of an array")
      }
    case ABytes(code, buf) =>
      attr match {
        case "length" | "size" => AInt(s"${KT}Size ($code)", "Length", None)
        case "first" =>
          ctx.need(s"not ${KT}Is_Empty ($code)")
          AInt(s"$buf ($code.First)", "U8", None)
        case "last" =>
          ctx.need(s"not ${KT}Is_Empty ($code)")
          AInt(s"$buf ($code.Last)", "U8", None)
        case "min" | "max" =>
          usedLibs += "Byte_Arrays"
          ctx.need(s"not ${KT}Is_Empty ($code)")
          AInt(s"Kaitai.Byte_Arrays.${attr.capitalize} ($buf, $code)", "U8", None)
        case _ => nt(s"`.$attr` of bytes")
      }
    case AStr(code, enc, buf) =>
      attr match {
        case "length" =>
          cc.encodingName(enc, Nil) match {
            case "Kaitai.Strings.Single_Byte" | "Kaitai.Strings.US_ASCII" => AInt(s"${KT}Size ($code)", "Length", None)
            case e => usedLibs += "Strings"; AInt(s"Kaitai.Strings.Character_Count ($buf, $code, $e)", "Length", None)
          }
        case _ => nt(s"`.$attr` of a string")
      }
    case i: AInt if attr == "to_i" => i
    case i: AInt if attr == "to_s" => AIntStr(i)
    case ABool(code) if attr == "to_i" => AInt(s"(if $code then 1 else 0)", "S64", None)
    case _ => nt(s"`.$attr` of $v")
  }

  private def element(ctx: Ctx, cs: ClassSpec, obj: String, a: AttrLikeSpec, ix: String, buf: String): AV = {
    val pkg = pkgOf(cs)
    val bs = cc.memberBase(a.id)
    val nm = cc.memberName(cs, a.id)
    useType(KT + "Length")
    ctx.need(s"$ix < $pkg.${bs}_Count ($obj)")
    val dt = a.dataType
    AdaTranslator.fixedElement(dt) match {
      case Some(_) =>
        dt match {
          case FloatMultiType(w, _) => AFloat(s"$pkg.${bs}_Bits ($obj, $buf, $ix)", w.width)
          case et: EnumType => AInt(s"$pkg.$nm ($obj, $buf, $ix)", adaInt(et.basedOn), et.enumSpec)
          case _ => AInt(s"$pkg.$nm ($obj, $buf, $ix)", adaInt(dt), None)
        }
      case None =>
        val e = ctx.name("E")
        ctx.step(List(s"$e : ${storedAda(dt)};"), List(s"$pkg.Get_$bs ($obj, $buf, $ix, $e);"))
        val v = valueOf(dt, e, buf)
        v match {
          case AUser(c, code, _) => ctx.need(s"${pkgOf(c)}.Valid ($code)")
          case _ =>
        }
        v
    }
  }

  // ------------------------------------------------------------ comparison

  private val IntRange: Map[String, (BigInt, BigInt)] = Map(
    "U8" -> (BigInt(0), BigInt(255)),
    "U16" -> (BigInt(0), BigInt(65535)),
    "U32" -> (BigInt(0), (BigInt(1) << 32) - 1),
    "U64" -> (BigInt(0), (BigInt(1) << 64) - 1),
    "S8" -> (BigInt(-128), BigInt(127)),
    "S16" -> (BigInt(-32768), BigInt(32767)),
    "S32" -> (-(BigInt(1) << 31), (BigInt(1) << 31) - 1),
    "S64" -> (-(BigInt(1) << 63), (BigInt(1) << 63) - 1),
    "Length" -> (BigInt(0), (BigInt(1) << 63) - 1)
  )

  private def aggregate(bytes: Seq[Int]): String = AdaTranslator.aggregate(bytes)

  private def adaString(s: String): String = "\"" + s.replace("\"", "\"\"") + "\""

  /** Value of an expected expression that is a constant integer, if it is one */
  private def intConst(e: Ast.expr): Option[(BigInt, Option[EnumSpec])] = e match {
    case Ast.expr.FloatNum(_) => None
    case Ast.expr.IntNum(n) => Some((n, None))
    case _ =>
      e.evaluateIntConst match {
        case Some(n) => Some((n, None))
        case None =>
          try {
            val t = tr.translateOperand(e)
            t.vt match {
              case VU64Lit(n) => Some((n, None))
              case VInt if t.isLiteral => Some((t.lo, None))
              case VEnum(sp) if t.isLiteral => Some((t.lo, Some(sp)))
              case _ => None
            }
          } catch { case _: Throwable => None }
      }
  }

  private def floatConst(e: Ast.expr): Option[BigDecimal] = e match {
    case Ast.expr.FloatNum(n) => Some(n)
    case Ast.expr.UnaryOp(Ast.unaryop.Minus, Ast.expr.FloatNum(n)) => Some(-n)
    // 0.5.as<f4>: the number as an f4 holds it
    case Ast.expr.CastToType(inner, t) if t.names == Seq("f4") => floatConst(inner).map(x => BigDecimal(x.toFloat.toDouble))
    case Ast.expr.CastToType(inner, t) if t.names == Seq("f8") => floatConst(inner)
    case _ => intConst(e).map(c => BigDecimal(c._1))
  }

  private def bytesConst(e: Ast.expr): Option[Seq[Int]] = e match {
    case Ast.expr.List(elts) =>
      val xs = elts.map(intConst)
      if (xs.forall(x => x.exists(c => c._1 >= 0 && c._1 <= 255))) Some(xs.map(_.get._1.toInt)) else None
    case Ast.expr.CastToType(inner, t) if t.names == Seq("bytes") => bytesConst(inner)
    case _ => None
  }

  private def charset(enc: String): Charset =
    try {
      enc.toUpperCase match {
        case "ASCII" => Charset.forName("US-ASCII")
        case _ => Charset.forName(enc)
      }
    } catch { case _: Throwable => nt(s"unknown string encoding $enc") }

  private def encodeStr(s: String, enc: String): Seq[Int] = {
    val encoder = charset(enc).newEncoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)
    try {
      val bb = encoder.encode(java.nio.CharBuffer.wrap(s))
      val arr = new Array[Byte](bb.remaining())
      bb.get(arr)
      arr.toSeq.map(_ & 0xff)
    } catch { case _: Throwable => nt(s"the string `$s` cannot be encoded as $enc") }
  }

  private def isByteEncoding(enc: String): Boolean = {
    val e = enc.toUpperCase
    !(e.startsWith("UTF-16") || e.startsWith("UTF-32") || e.startsWith("UCS") || e.startsWith("UTF-7"))
  }

  private def adaFloat(x: BigDecimal): String = {
    val s = x.bigDecimal.toPlainString
    if (s.contains(".")) s else s + ".0"
  }

  /** Ada condition that says the value equals the expected expression. */
  private def compare(v: AV, expected: Ast.expr): String = (v, expected) match {
    case (AInt(code, ada, vspec), _) if floatConst(expected).isDefined && intConst(expected).isEmpty =>
      nt("integer compared with a float")
    case (i: AInt, _) =>
      val (n, espec) = intConst(expected).getOrElse(nt(s"expected value `${src(expected)}` is not an integer constant"))
      compareInt(i, n, espec, expected)
    case (ABool(code), Ast.expr.Bool(b)) => if (b) code else s"not $code"
    case (AFloat(bits, w), _) =>
      val x = floatConst(expected).getOrElse(nt(s"expected value `${src(expected)}` is not a number"))
      usedLibs += "Floats"
      val conv = if (w == 4) s"Long_Float (Kaitai.Floats.To_F32 ($bits))" else s"Kaitai.Floats.To_F64 ($bits)"
      val tol = BigDecimal("0.000001") * x.abs.max(BigDecimal(1))
      s"Kaitai.Floats.Is_Finite ($bits) and then abs ($conv - ${adaFloat(x)}) <= ${adaFloat(tol)}"
    case (AF64(code), _) =>
      val x = floatConst(expected).getOrElse(nt(s"expected value `${src(expected)}` is not a number"))
      val tol = BigDecimal("0.000001") * x.abs.max(BigDecimal(1))
      s"abs ($code - ${adaFloat(x)}) <= ${adaFloat(tol)}"
    case (AStr(code, enc, buf), Ast.expr.Str(s)) =>
      if (s.forall(c => c >= 32 && c <= 126) && isByteEncoding(enc)) {
        usedLibs += "Strings"
        s"Kaitai.Strings.Equal_Literal ($buf, $code, ${adaString(s)})"
      } else {
        usedLibs += "Byte_Arrays"
        s"Kaitai.Byte_Arrays.Equal ($buf, $code, ${aggregate(encodeStr(s, enc))})"
      }
    case (ABytes(code, buf), _) if bytesConst(expected).isDefined =>
      usedLibs += "Byte_Arrays"
      s"Kaitai.Byte_Arrays.Equal ($buf, $code, ${aggregate(bytesConst(expected).get)})"
    case (AIntStr(i), Ast.expr.Str(s)) =>
      val canonical = scala.util.Try(BigInt(s)).toOption.filter(_.toString == s)
      canonical match {
        case Some(n) => compareInt(i, n, None, expected)
        case None => "False"
      }
    case (_, Ast.expr.Name(Ast.identifier("null"))) => nt("`null` expected")
    case (AAbsent(_), _) => nt("absent member compared with a value")
    case (other, _) => nt(s"comparison of ${other.getClass.getSimpleName} with `${src(expected)}`")
  }

  private def compareInt(i: AInt, n: BigInt, espec: Option[EnumSpec], expected: Ast.expr): String = {
    val (lo, hi) = IntRange(i.ada)
    if (n < lo || n > hi) return "False"
    // an enumeration is compared by its literal where the label is known
    (espec, i.enum) match {
      case (Some(sp), Some(sp2)) if sp.name == sp2.name && i.ada != "U64" =>
        expected match {
          case Ast.expr.EnumByLabel(_, label, _) =>
            val owner = pkgOfNames(sp.name.dropRight(1))
            val en = base(sp.name.last) + "_Enum"
            val lit = s"$owner.${base(sp.name.last)}_${base(label.name)}"
            useType(s"$owner.$en")
            val arg = if (i.ada == "S64") i.code else s"${KT}S64 (${i.code})"
            return s"$owner.Is_$en ($arg) and then $owner.To_$en ($arg) = $lit"
          case _ =>
        }
      case _ =>
    }
    useType(KT + i.ada)
    s"${i.code} = $n"
  }

  // ------------------------------------------------------- arrays of values

  /** Condition that the repeated member equals a list of constants; elements that need a fetch add steps */
  private def compareArray(ctx: Ctx, arr: AArr, elts: Seq[Ast.expr]): String = {
    val pkg = pkgOf(arr.cs)
    val bs = cc.memberBase(arr.a.id)
    useType(KT + "Length")
    val countIs = s"$pkg.${bs}_Count (${arr.obj}) = ${elts.size}"
    AdaTranslator.fixedElement(arr.a.dataType) match {
      case Some(_) =>
        val parts = elts.zipWithIndex.map { case (e, k) =>
          compare(elementIn(ctx, arr, k.toString), e)
        }
        (countIs :: parts.toList).mkString(" and then ")
      case None =>
        // fetch all the elements first, the number of them has to be right
        ctx.need(countIs)
        val vals = ListBuffer[AV]()
        val decls = ListBuffer[String]()
        val stmts = ListBuffer[String]()
        elts.indices.foreach { k =>
          val e = ctx.name("E")
          decls += s"$e : ${storedAda(arr.a.dataType)};"
          stmts += s"$pkg.Get_$bs (${arr.obj}, ${arr.buf}, $k, $e);"
          vals += valueOf(arr.a.dataType, e, arr.buf)
        }
        ctx.step(decls.toList, stmts.toList)
        elts.zip(vals).map { case (e, v) => compare(v, e) }.mkString(" and then ") match {
          case "" => "True"
          case c => c
        }
    }
  }

  /** The element of a fixed-size repetition, no step needed; the index is known to be below the count */
  private def elementIn(ctx: Ctx, arr: AArr, ix: String): AV = {
    val pkg = pkgOf(arr.cs)
    val bs = cc.memberBase(arr.a.id)
    val nm = cc.memberName(arr.cs, arr.a.id)
    arr.a.dataType match {
      case FloatMultiType(w, _) => AFloat(s"$pkg.${bs}_Bits (${arr.obj}, ${arr.buf}, $ix)", w.width)
      case et: EnumType => AInt(s"$pkg.$nm (${arr.obj}, ${arr.buf}, $ix)", adaInt(et.basedOn), et.enumSpec)
      case dt => AInt(s"$pkg.$nm (${arr.obj}, ${arr.buf}, $ix)", adaInt(dt), None)
    }
  }

  // ------------------------------------------------------------ the program

  private def src(e: Ast.expr): String = e match {
    case Ast.expr.Name(Ast.identifier(RootName)) => ""
    case Ast.expr.Name(Ast.identifier(n)) => n
    case Ast.expr.Attribute(Ast.expr.Name(Ast.identifier(RootName)), Ast.identifier(a)) => a
    case Ast.expr.Attribute(v, Ast.identifier(a)) => src(v) + "." + a
    case Ast.expr.Subscript(v, i) => src(v) + "[" + src(i) + "]"
    case Ast.expr.CastToType(v, t) => src(v) + ".as<" + t.nameAsStr + ">"
    case Ast.expr.Call(Ast.expr.Attribute(v, Ast.identifier(m)), args) => src(v) + "." + m + "(" + args.map(src).mkString(", ") + ")"
    case Ast.expr.IntNum(n) => n.toString
    case Ast.expr.FloatNum(n) => n.toString
    case Ast.expr.Str(s) => "\"" + s + "\""
    case Ast.expr.Bool(b) => b.toString
    case Ast.expr.List(es) => es.map(src).mkString("[", ", ", "]")
    case Ast.expr.UnaryOp(_, v) => "-" + src(v)
    case Ast.expr.EnumByLabel(en, l, _) => en.name + "::" + l.name
    case other => other.toString
  }

  /** Statements that check assert `n`, as lines at the given indentation */
  private def genAssert(n: Int, a: TestAssert): List[String] = {
    val ctx = new Ctx
    val (actual, source) = a match {
      case TestEquals(act, _) => (act, src(act))
      case TestException(act, ConversionError) => (act, src(act))
      case TestException(act, _) => nt(s"assert ${n} expects an exception of the access to `${src(act)}`")
    }
    val check = a match {
      case TestEquals(act, exp) =>
        exp match {
          case Ast.expr.Name(Ast.identifier("null")) =>
            eval(ctx, act, absent = true) match {
              case AAbsent(c) => c
              case _ => nt("`null` expected, but the member cannot be absent")
            }
          case _ =>
            (eval(ctx, act), exp) match {
              case (arr: AArr, Ast.expr.List(elts)) => compareArray(ctx, arr, elts)
              case (v, _) => compare(v, exp)
            }
        }
      case TestException(act, _) =>
        // a conversion that fails (`"abc".to_i`) has no value here: the instance is not defined
        eval(ctx, act, absent = true) match {
          case AAbsent(c) => c
          case _ => nt("an exception expected, but the member is always defined")
        }
    }
    val q = adaString(source)
    emit(ctx.steps.toList, ctx.guards.toList, n, q, check, 3)
  }

  private def emit(steps: List[Step], finalGuards: List[String], n: Int, q: String, check: String, level: Int): List[String] = {
    val pad = indentStr * level
    def guarded(gs: List[String], body: Int => List[String]): List[String] =
      if (gs.isEmpty) body(level)
      else {
        val cond = gs.map(g => if (g.contains(" or ") || g.contains(" and ") && gs.size > 1) s"($g)" else g)
        List(s"${pad}if ${cond.mkString(" and then ")} then") ++ body(level + 1) ++
          List(s"${pad}else", s"$pad${indentStr}Undefined ($n, $q);", s"${pad}end if;")
      }
    steps match {
      case Nil =>
        guarded(finalGuards, l => List(s"${indentStr * l}Check ($n, $q, $check);"))
      case s :: rest =>
        guarded(s.guards, l => {
          val p = indentStr * l
          List(s"${p}declare") ++ s.decls.map(d => s"$p$indentStr$d") ++ List(s"${p}begin") ++
            s.stmts.map(x => s"$p$indentStr$x") ++
            emit(rest, finalGuards, n, q, check, l + 1) ++ s.cleanup.map(x => s"$p$indentStr$x") ++ List(s"${p}end;")
        })
    }
  }

  private val statusOf: PartialFunction[KSError, String] = {
    case EndOfStreamError => "End_Of_Stream"
    case UndecidedEndiannessError => "Undecided_Endianness"
    case _: ValidationNotEqualError => "Validation_Not_Equal"
    case _: ValidationLessThanError => "Validation_Less_Than"
    case _: ValidationGreaterThanError => "Validation_Greater_Than"
    case _: ValidationNotAnyOfError => "Validation_Not_Any_Of"
    case _: ValidationNotInEnumError => "Validation_Not_In_Enum"
    case _: ValidationExprError => "Validation_Expr"
  }

  override def run(): Unit = {
    try {
      text = generate()
    } catch {
      case e: AdaNotTranslated => text = s"--  NOT TRANSLATED: ${e.getMessage.replace('\n', ' ')}\n"
      case e: AdaUnsupported => text = s"--  NOT TRANSLATED: ${e.getMessage.replace('\n', ' ')}\n"
    }
  }

  /** Arguments for the parameters of the top-level type, for experiments with a description that has some */
  private val topArgs: Option[String] = sys.env.get("ADA_SG_TOP_ARGS").filter(_.nonEmpty)

  /** Set by the script with `--round-trip`: the program writes the parsed value again and compares it with the input */
  private val roundTrip: Boolean = sys.env.get("ADA_SG_ROUND_TRIP").exists(v => v.nonEmpty && v != "0")

  /** Arguments of `Parse` between the stream and the result */
  private def parseArgs: String =
    topArgs.map(", " + _).getOrElse("") + (if (isRecursiveTop) ", " + topPkg + ".Max_Depth" else "")

  private def isRecursiveTop: Boolean =
    top.seq.exists(a => containsSelf(a.dataType)) ||
      top.instances.values.exists { case pi: ParseInstanceSpec => containsSelf(pi.dataType); case _ => false }

  /**
    * Writes R with the `Write` of the top-level type into an array of 2 x input + 16 bytes, so that a longer
    * output is seen as a difference. C is what `Parse` consumed, N what `Write` produced.
    *   same       N = C and the bytes are the first C bytes of the input
    *   canonical  not the same, but the output parses again and writing that value gives the same output
    *   differs / not written: failures
    */
  private def roundTripLines(asserts: List[String]): List[String] = {
    usedLibs += "Writers"
    useType(KT + "U8")
    useType(KT + "Bytes")
    val args = if (cc.hasBelongs(top)) "R, Buffer.all" else "R"
    val args2 = if (cc.hasBelongs(top)) "R2, Output" else "R2"
    val body = List(
      "declare",
      "   Capacity : constant Kaitai.Types.Length := 2 * Size + 16;",
      "   Target   : Buffer_Access := new Kaitai.Types.Bytes (1 .. Capacity);",
      "   W        : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target.all);",
      "   C        : constant Kaitai.Types.Length := Kaitai.Streams.Pos (S);",
      "begin",
      s"   $topPkg.Write ($args, Target.all, W);",
      "   if not Kaitai.Writers.OK (W) then",
      "      Fail (\"round trip: not written (\" & Kaitai.Types.Status_Kind'Image (Kaitai.Writers.Status (W)) & \")\");",
      "   else",
      "      declare",
      "         N      : constant Kaitai.Types.Length := Kaitai.Types.Size (Kaitai.Writers.Written (W));",
      "         Common : constant Kaitai.Types.Length := Kaitai.Types.Length'Min (N, C);",
      "         First  : Kaitai.Types.Length := Common;",
      "         Same   : Boolean := N = C;",
      "      begin",
      "         for I in 1 .. Common loop",
      "            if Target (I) /= Buffer (I) then",
      "               First := I - 1;",
      "               Same := False;",
      "               exit;",
      "            end if;",
      "         end loop;",
      "         if Same then",
      "            Put_Line (\"round trip: same\");",
      "         else",
      "            declare",
      "               Output   : Kaitai.Types.Bytes renames Target (1 .. N);",
      "               S2       : Kaitai.Streams.Stream := Kaitai.Streams.Open (Output);",
      s"               R2       : $topPkg.T;",
      "               Target2  : Buffer_Access := new Kaitai.Types.Bytes (1 .. Capacity);",
      "               W2       : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target2.all);",
      "               Canonical : Boolean := False;",
      "               Values_Differ : Boolean := False;",
      "            begin",
      s"               $topPkg.Parse (R2, Output, S2$parseArgs);",
      s"               if $topPkg.Valid (R2) then",
      s"                  $topPkg.Write ($args2, Target2.all, W2);",
      "                  Canonical := Kaitai.Writers.OK (W2)",
      "                    and then Kaitai.Types.Size (Kaitai.Writers.Written (W2)) = N",
      "                    and then Target2 (1 .. N) = Output;",
      "               end if;",
    ) ++ replayAsserts(asserts) ++ List(
      "               if Canonical and then not Values_Differ then",
      "                  Put_Line",
      "                    (\"round trip: canonical (first difference at \" & Num (First) & \", wrote \" & Num (N) & \" of \" & Num (C) & \")\");",
      "               elsif Canonical then",
      "                  Fail (\"round trip: differs at \" & Num (First) & \" (wrote \" & Num (N) & \" of \" & Num (C) & \", the output parses but the asserts do not hold for it)\");",
      "               else",
      "                  Fail (\"round trip: differs at \" & Num (First) & \" (wrote \" & Num (N) & \" of \" & Num (C) & \")\");",
      "               end if;",
      "               Free (Target2);",
      "            end;",
      "         end if;",
      "      end;",
      "   end if;",
      "   Free (Target);",
      "end;"
    )
    body.map(l => indentStr * 3 + l)
  }

  /** The asserts again, on the value parsed from the output: any that does not hold sets `Values_Differ` */
  private def replayAsserts(asserts: List[String]): List[String] =
    if (asserts.isEmpty) Nil
    else
      List(
        "               if Canonical then",
        "                  declare",
        "                     Buffer : Buffer_Access := new Kaitai.Types.Bytes'(Output);",
        "                     R      : constant " + topPkg + ".T := R2;",
        "                     S      : constant Kaitai.Streams.Stream := S2;",
        "                  begin",
        "                     Values_Hold := True;"
      ) ++ asserts.map(_.trim).map(l => "                     " + l.replace("Check (", "Check_Again (").replace("Undefined (", "Undefined_Again (")) ++ List(
        "                     Values_Differ := not Values_Hold;",
        "                     Free (Buffer);",
        "                  end;",
        "               end if;"
      )

  /** The data type is, or chooses among, the type of the top-level class itself */
  private def containsSelf(dt: DataType): Boolean = dt match {
    case ut: UserType => ut.classSpec.exists(_ eq top)
    case st: SwitchType => st.cases.values.exists(containsSelf)
    case _ => false
  }

  private def generate(): String = {
    if (top.params.nonEmpty && topArgs.isEmpty)
      nt("the top-level type has parameters, which a .kst cannot supply (ADA_SG_TOP_ARGS can, for experiments)")
    withPkgs += base(top.name.head)
    val id = spec.id
    val body = ListBuffer[String]()
    spec.exception match {
      case Some(ex) =>
        val expected = statusOf.lift(ex.exception)
        if (expected.isDefined) useType(KT + "Status_Kind")
        body += s"${indentStr * 2}if $topPkg.Valid (R) then"
        body += s"${indentStr * 3}Fail (\"parse succeeded, expected ${ex.exception.name}\");"
        expected match {
          case Some(st) =>
            body += s"${indentStr * 2}elsif Kaitai.Streams.Status (S) = ${KT}$st then"
            body += s"${indentStr * 3}Put_Line (\"ok parse failed with $st\");"
            body += s"${indentStr * 2}else"
            body += s"${indentStr * 3}Fail (\"parse failed with \" & ${KT}Status_Kind'Image (Kaitai.Streams.Status (S)) & \", expected $st\");"
          case None =>
            body += s"${indentStr * 2}else"
            body += s"${indentStr * 3}--  the runtime cannot tell ${ex.exception.name} apart: any failure is accepted"
            body += s"${indentStr * 3}Put_Line (\"ok parse failed with \" & ${KT}Status_Kind'Image (Kaitai.Streams.Status (S)));"
        }
        body += s"${indentStr * 2}end if;"
      case None =>
        val asserts = spec.asserts.zipWithIndex.map { case (a, i) => (i + 1, a) }
        val generated = asserts.map { case (n, a) => (n, a, genAssert(n, a)) }
        body += s"${indentStr * 2}if not $topPkg.Valid (R) then"
        body += s"${indentStr * 3}Fail (\"parse failed with \" & ${KT}Status_Kind'Image (Kaitai.Streams.Status (S)));"
        generated.foreach { case (n, a, _) =>
          val source = a match { case TestEquals(act, _) => src(act); case TestException(act, _) => src(act) }
          body += s"${indentStr * 3}Undefined ($n, ${adaString(source)});"
        }
        body += s"${indentStr * 2}else"
        if (generated.isEmpty) body += s"${indentStr * 3}Put_Line (\"ok parse\");"
        generated.foreach { case (_, _, lines) => body ++= lines }
        if (roundTrip) body ++= roundTripLines(generated.flatMap(_._3))
        body += s"${indentStr * 2}end if;"
    }

    val recursive = top.seq.exists(a => containsSelf(a.dataType)) ||
      top.instances.values.exists { case pi: ParseInstanceSpec => containsSelf(pi.dataType); case _ => false }
    val libs = (List("Streams", "Types") ++ usedLibs).distinct
    val sb = new StringBuilder
    def p(s: String): Unit = sb.append(s).append("\n")
    val helpers = spec.exception.isEmpty && spec.asserts.nonEmpty
    def ph(s: String): Unit = if (helpers) p(s)
    p(s"--  $AUTOGEN_COMMENT")
    p(s"--  Test $id, data ${spec.data}")
    p("")
    p("with Ada.Command_Line;")
    p("with Ada.Text_IO;")
    p("with Ada.Unchecked_Deallocation;")
    p("with Kaitai.Files;")
    libs.sorted.foreach(l => p(s"with Kaitai.$l;"))
    withPkgs.toList.sorted.foreach(w => p(s"with $w;"))
    p("")
    p(s"procedure Test_$id is")
    p("")
    (useTypes + (KT + "Length")).toList.sorted.foreach(t => p(s"   use type $t;"))
    p("")
    p("   type Buffer_Access is access Kaitai.Types.Bytes;")
    p("   procedure Free is new Ada.Unchecked_Deallocation (Kaitai.Types.Bytes, Buffer_Access);")
    p("")
    p("   Directory : constant String :=")
    p("     (if Ada.Command_Line.Argument_Count >= 1 then Ada.Command_Line.Argument (1) else \"src\");")
    p(s"   File      : constant String := Directory & \"/${spec.data}\";")
    p("   Buffer    : Buffer_Access := null;")
    p("   Failures  : Natural := 0;")
    p("")
    p("   procedure Put_Line (Item : String) renames Ada.Text_IO.Put_Line;")
    p("")
    if (roundTrip) {
      p("   function Num (N : Kaitai.Types.Length) return String is")
      p("      Image : constant String := Kaitai.Types.Length'Image (N);")
      p("   begin")
      p("      return Image (Image'First + 1 .. Image'Last);")
      p("   end Num;")
      p("")
      p("   --  The asserts again, on the value parsed from what Write produced: they only set Values_Hold")
      p("   Values_Hold : Boolean := True;")
      p("")
      if (spec.asserts.nonEmpty) {
        p("   procedure Undefined_Again (N : Natural; Source : String) is")
        p("      pragma Unreferenced (N, Source);")
        p("   begin")
        p("      Values_Hold := False;")
        p("   end Undefined_Again;")
        p("")
        p("   procedure Check_Again (N : Natural; Source : String; Result : Boolean) is")
        p("      pragma Unreferenced (N, Source);")
        p("   begin")
        p("      if not Result then")
        p("         Values_Hold := False;")
        p("      end if;")
        p("   end Check_Again;")
        p("")
      }
    }
    ph("   function Img (N : Natural) return String is")
    ph("      Image : constant String := Natural'Image (N);")
    ph("   begin")
    ph("      return Image (Image'First + 1 .. Image'Last);")
    ph("   end Img;")
    ph("")
    p("   procedure Fail (Message : String) is")
    p("   begin")
    p("      Failures := Failures + 1;")
    p("      Put_Line (\"FAIL \" & Message);")
    p("   end Fail;")
    p("")
    ph("   --  The value of the assert does not exist: a condition of its access does not hold")
    ph("   procedure Undefined (N : Natural; Source : String) is")
    ph("   begin")
    ph("      Fail (Img (N) & \": \" & Source & \" (not defined)\");")
    ph("   end Undefined;")
    ph("")
    ph("   procedure Check (N : Natural; Source : String; Result : Boolean) is")
    ph("   begin")
    ph("      if Result then")
    ph("         Put_Line (\"ok \" & Img (N));")
    ph("      else")
    ph("         Fail (Img (N) & \": \" & Source);")
    ph("      end if;")
    ph("   end Check;")
    ph("")
    p("   Size   : Kaitai.Types.Length;")
    p("   Last   : Kaitai.Types.Length;")
    p("   Result : Kaitai.Files.Result_Kind;")
    p("")
    p("begin")
    p("   Kaitai.Files.Get_Size (File, Size, Result);")
    p("   if Result not in Kaitai.Files.Done then")
    p("      Put_Line (\"ERROR cannot read \" & File);")
    p("      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);")
    p("      return;")
    p("   end if;")
    p("   Buffer := new Kaitai.Types.Bytes (1 .. Size);")
    p("   Kaitai.Files.Read (File, Buffer.all, Last, Result);")
    p("   if Result not in Kaitai.Files.Done or else Last /= Size then")
    p("      Put_Line (\"ERROR cannot read \" & File);")
    p("      Free (Buffer);")
    p("      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);")
    p("      return;")
    p("   end if;")
    p("")
    p("   declare")
    p("      S : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer.all);")
    p(s"      R : $topPkg.T;")
    p("   begin")
    p(s"      $topPkg.Parse (R, Buffer.all, S$parseArgs);")
    body.foreach(l => p(l))
    p("   end;")
    p("   Free (Buffer);")
    p("")
    p("   if Failures = 0 then")
    p("      Put_Line (\"PASSED\");")
    p("   else")
    p("      Put_Line (\"FAILED\");")
    p("      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);")
    p("   end if;")
    p(s"end Test_$id;")
    sb.toString
  }
}

object AdaSG
