package io.kaitai.struct.testtranslator.specgenerators

import java.io.{File, PrintWriter}

import io.kaitai.struct.{AdaClassCompiler, ClassTypeProvider, RuntimeConfig, Utils}
import io.kaitai.struct.JavaMain.CLIConfig
import io.kaitai.struct.datatype.DataType._
import io.kaitai.struct.datatype._
import io.kaitai.struct.format._
import io.kaitai.struct.formats.JavaKSYParser
import io.kaitai.struct.languages.PythonCompiler
import io.kaitai.struct.problems.ProblemSeverity
import io.kaitai.struct.translators.{AdaTranslator, AdaUnsupported}

import scala.collection.mutable
import scala.collection.mutable.ListBuffer

/**
  * Generator of the dump programs of scripts/diff-python.sh.
  *
  * For a description it writes two programs that print the same canonical dump
  * of everything in a parsed value: `dump_<name>.adb` (against the Ada parser
  * of the backend) and `dump_<name>.py` (against the Python parser of the same
  * compiler build). Both are written from the same list of members of every
  * type, so they print the same paths in the same order. A program takes
  * file names; for each it prints `@@ <file>`, then either the lines of the
  * dump or the single line `FAILED` (any failure while walking the whole
  * value) or `EXCEPTION <name>` (Ada only: the program raised), and lines
  * that start with `#why` that say why, which a comparison ignores.
  *
  * A line of the dump is `path = value`: integers and enumerations in
  * decimal, booleans 0 or 1, floats as the hex of their bits (`nan` for every
  * NaN), bytes and strings as the hex of the raw bytes, `absent` for a member
  * that is not there, `path.size = N` for a repetition, `path.case = Name`
  * for the chosen case of a switch whose cases are not all integers.
  *
  * Usage: AdaDiff FORMATS_DIRS IMPORT_DIR OUT_DIR NAME...
  * writes OUT_DIR/NAME/dump_NAME.adb, dump_NAME.py and NAME.leaves (a line
  * `skipped: reason` instead if the dump cannot be generated).
  */
object AdaDiff {
  def main(args: Array[String]): Unit = {
    if (args.length < 4) {
      Console.err.println("usage: AdaDiff FORMATS_DIR IMPORT_DIR OUT_DIR NAME...")
      sys.exit(2)
    }
    // the directories of the descriptions, separated by `:`; a name is looked for in them in turn
    val formatsDirs = args(0).split(":").toList
    val importDir = args(1)
    val outDir = args(2)
    args.drop(3).foreach { name =>
      val dir = new File(s"$outDir/$name")
      dir.mkdirs()
      def write(file: String, text: String): Unit = {
        val w = new PrintWriter(new File(dir, file), "UTF-8")
        try w.write(text) finally w.close()
      }
      try {
        val cliConfig = CLIConfig(importPaths = formatsDirs :+ importDir)
        val dir0 = formatsDirs.find(d => new File(s"$d/$name.ksy").exists).getOrElse(formatsDirs.head)
        val (specsOpt, errors) = JavaKSYParser.localFileToSpecs(s"$dir0/$name.ksy", cliConfig)
        if (errors.exists(p => p.severity != ProblemSeverity.Warning) || specsOpt.isEmpty)
          throw new AdaDiffSkip("the description does not load")
        val specs = specsOpt.get
        val provider = new ClassTypeProvider(specs, specs.firstSpec)
        val gen = new AdaDiff(name, specs.firstSpec, provider)
        gen.run()
        write(s"dump_$name.adb", gen.adaText)
        write(s"dump_$name.py", gen.pyText)
      } catch {
        case e: AdaDiffSkip => write("skipped", e.getMessage.replace('\n', ' ') + "\n")
        case e: AdaUnsupported => write("skipped", e.getMessage.replace('\n', ' ') + "\n")
      }
    }
  }
}

/** The dump cannot be generated for this description; the message is the reason */
class AdaDiffSkip(msg: String) extends RuntimeException(msg)

class AdaDiff(name: String, top: ClassSpec, provider: ClassTypeProvider) {
  private val cc = new AdaClassCompiler(provider.allClasses, top, RuntimeConfig())
  private val tr = new AdaTranslator(provider, cc)

  private val KT = "Kaitai.Types."
  private def skip(msg: String): Nothing = throw new AdaDiffSkip(msg)

  var adaText = ""
  var pyText = ""

  // ------------------------------------------------------------- type table

  private val ids = mutable.LinkedHashMap[String, Int]()
  private val classes = mutable.LinkedHashMap[String, ClassSpec]()
  private val queue = mutable.Queue[ClassSpec]()

  /** Number of the dump procedure of a class; the class is generated later */
  private def procOf(cs: ClassSpec): Int = ids.getOrElseUpdate(cs.nameAsStr, {
    classes(cs.nameAsStr) = cs
    queue.enqueue(cs)
    ids.size + 1
  })

  private def pkgOf(cs: ClassSpec): String = cc.fullPackageOf(cs)
  private val withs = mutable.LinkedHashSet[String]()

  private def adaInt(dt: DataType): String = dt match {
    case CalcIntType => "S64"
    case _ => AdaTranslator.intInfo(dt).map(_._1).getOrElse(skip(s"integer type $dt"))
  }

  private def storedAda(dt: DataType): String = dt match {
    case et: EnumType => KT + adaInt(et.basedOn)
    case _: IntType => KT + adaInt(dt)
    case _: BooleanType => "Boolean"
    case FloatMultiType(w, _) => if (w.width == 4) KT + "U32" else KT + "U64"
    case _: BytesType | _: StrType => KT + "Slice"
    case ut: UserType => pkgOf(ut.classSpec.get) + ".T"
    case other => skip(s"type $other")
  }

  private def isIntCase(dt: DataType): Boolean = dt match {
    case _: IntType | _: EnumType => true
    case _ => false
  }

  private def idStr(id: Identifier): String = id.humanReadable

  // ----------------------------------------------------------- the members

  /** What a dump walks in a type: parameters, stored fields, instances (in the order of the description) */
  private def members(cs: ClassSpec): List[MemberSpec] = {
    // a parameter that is not an integer, a boolean or an enumeration is not kept: the parser gets what the type uses of it
    val params: List[MemberSpec] = cs.params.filter(p => p.dataType match {
      case _: IntType | _: EnumType | _: BooleanType => true
      case _ => false
    })
    val seq: List[MemberSpec] = cs.seq.filter(a => cc.isStored(a))
    // an instance that is a repeated field under another name has no accessors of its own; the field is dumped
    val inst: List[MemberSpec] = cs.instances.values.toList.filter {
      case v: ValueInstanceSpec => !v.dataType.isInstanceOf[ArrayType]
      case _ => true
    }
    params ++ seq ++ inst
  }

  /** Encoding of the string that a value instance holds, if its expression is a field */
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

  private def encodingOf(cs: ClassSpec, m: MemberSpec, dt: DataType): String = dt match {
    case StrFromBytesType(_, enc, _) => enc
    case _ => m match {
      case v: ValueInstanceSpec => instanceEncoding(cs, v)
      case _ => "UTF-8"
    }
  }

  /** The name of the attribute of a member in the Python object: instances are properties, `_m_x` holds the value */
  private def pyAttr(id: Identifier): String = id match {
    case InstanceIdentifier(n) => n
    case other => PythonCompiler.idToStr(other)
  }

  private def pyLit(s: String): String = "'" + s.flatMap {
    case '\\' => "\\\\"
    case '\'' => "\\'"
    case '\n' => "\\n"
    case c => c.toString
  } + "'"

  private def pyClassName(cs: ClassSpec): String = cs.name.map(Utils.upperCamelCase).mkString(".")

  // ------------------------------------------------------------------- Ada

  private val adaOut = ListBuffer[String]()
  private var fresh = 0
  private def nm(p: String): String = { fresh += 1; s"$p$fresh" }

  private def ind(ls: List[String], n: Int = 1): List[String] = ls.map(l => if (l.isEmpty) l else ("   " * n) + l)

  /** A block `declare decls begin stmts end;` */
  private def blk(decls: List[String], stmts: List[String]): List[String] =
    List("declare") ++ ind(decls) ++ List("begin") ++ ind(stmts) ++ List("end;")

  /** Statements that print a leaf: value of Ada type `dt` in `code` (floats: raw bits; enums: the integer) */
  private def adaLeaf(dt: DataType, code: String, buf: String, path: String): List[String] = dt match {
    case _: BooleanType => List(s"Put_Bool ($path, $code);")
    case et: EnumType => adaLeaf(et.basedOn, code, buf, path)
    case _: IntType =>
      val signed = dt == CalcIntType || AdaTranslator.intInfo(dt).exists(_._2 < 0)
      if (signed) List(s"Put_S ($path, ${KT}S64 ($code));") else List(s"Put_U ($path, ${KT}U64 ($code));")
    case FloatMultiType(w, _) => List(s"Put_Float${w.width} ($path, $code);")
    case CalcFloatType => List(s"Put_Double ($path, $code);")
    case _: BytesType | _: StrType => List(s"Put_Hex ($path, $buf, $code);")
    case ut: UserType if ut.classSpec.get.meta.isOpaque => skip(s"the opaque type ${ut.classSpec.get.nameAsStr}, whose members are not known")
    case ut: UserType =>
      val cs = ut.classSpec.get
      val p = procOf(cs)
      val v = nm("V")
      val belongs = if (cc.hasBelongs(cs)) s" or else not ${pkgOf(cs)}.Belongs_To ($v, $buf)" else ""
      blk(List(s"$v : constant ${pkgOf(cs)}.T := $code;"), List(
        s"if not ${pkgOf(cs)}.Valid ($v)$belongs then",
        s"   Fail (\"invalid \" & $path);",
        "else",
        s"   Dump_$p ($buf, $v, $path);",
        "end if;"))
    case other => skip(s"value of type $other")
  }

  private def adaMember(cs: ClassSpec, m: MemberSpec, obj: String, buf: String, path: String): List[String] = {
    val pkg = pkgOf(cs)
    val mname = cc.memberName(cs, m.id)
    val bs = cc.memberBase(m.id)
    val has = s"$pkg.${cc.presenceName(cs, m.id)}"
    def absent: List[String] = List(s"Put_Absent ($path);")
    m match {
      case p: ParamDefSpec =>
        p.dataType match {
          case et: EnumType => adaLeaf(et, s"$pkg.${bs}_Value ($obj)", buf, path)
          case dt => adaLeaf(dt, s"$pkg.$mname ($obj)", buf, path)
        }
      case a: AttrSpec =>
        val body: List[String] =
          if (a.cond.repeat != NoRepeat) adaRepeat(cs, a, obj, buf, path)
          else a.dataType match {
            case st: SwitchType => adaSwitch(cs, a, st, obj, buf, path)
            case dt if AdaTranslator.hasProcess(dt) => adaProcessed(cs, a, dt, obj, buf, path)
            case ut: UserType if ut.classSpec.exists(_ eq cs) =>
              val l = nm("L")
              val o = nm("Outcome")
              blk(List(s"$l : $pkg.T;", s"$o : ${KT}Status_Kind;"), List(
                s"$pkg.$mname ($obj, $buf, $l, $o);",
                s"if $o /= ${KT}Success then",
                s"   Fail (\"outcome \" & ${KT}Status_Kind'Image ($o) & \" \" & $path);",
                "else") ++ ind(adaLeaf(ut, l, buf, path)) ++ List("end if;"))
            case dt: EnumType => adaLeaf(dt, s"$pkg.${bs}_Value ($obj)", buf, path)
            case dt: FloatType => adaLeaf(dt, s"$pkg.${bs}_Bits ($obj)", buf, path)
            case dt => adaLeaf(dt, s"$pkg.$mname ($obj)", buf, path)
          }
        if (a.cond.ifExpr.isDefined) List(s"if $has ($obj) then") ++ ind(body) ++ List("else") ++ ind(absent) ++ List("end if;")
        else body
      case v: ValueInstanceSpec =>
        val usesBuf = cc.valueInstanceUsesBuffer(cs, v)
        val args = if (usesBuf) s"$obj, $buf" else obj
        val code = v.dataType match {
          case _: EnumType => s"$pkg.${bs}_Value ($args)"
          case _ => s"$pkg.$mname ($args)"
        }
        val dt = v.dataType match {
          case et: EnumType => CalcIntType   // the accessor returns S64
          case _: FloatType => CalcFloatType   // the accessor returns F64
          case other => other
        }
        // an instance that is a literal above the largest S64 returns U64
        val leaf =
          if (cc.valueInstanceIsU64(cs, v)) List(s"Put_U ($path, ${KT}U64 ($code));")
          else adaLeaf(dt, code, buf, path)
        // Has_X is false if the condition of the instance does not hold, but also if its expression is
        // not defined: the API does not tell the two apart, so an instance with `if` is `absent` then
        if (cc.valueInstanceHasGuard(cs, v) && v.ifExpr.isDefined)
          List(s"if $has ($args) then") ++ ind(leaf) ++ List("else") ++ ind(absent) ++ List("end if;")
        else if (cc.valueInstanceHasGuard(cs, v))
          List(s"if $has ($args) then") ++ ind(leaf) ++ List("else", s"   Fail (\"undefined \" & $path);", "end if;")
        else leaf
      case p: ParseInstanceSpec if cc.instanceNotKept(cs, p).isEmpty =>
        // Parse kept it, and the accessor is a function
        p.dataType match {
          case et: EnumType => adaLeaf(et, s"$pkg.${bs}_Value ($obj)", buf, path)
          case dt => adaLeaf(dt, s"$pkg.$mname ($obj)", buf, path)
        }
      case p: ParseInstanceSpec =>
        val l = nm("L")
        val o = nm("Outcome")
        val leaf = blk(List(s"$l : ${storedAda(p.dataType)};", s"$o : ${KT}Status_Kind;"), List(
          s"$pkg.$mname ($obj, $buf, $l, $o);",
          s"if $o /= ${KT}Success then",
          s"   Fail (\"outcome \" & ${KT}Status_Kind'Image ($o) & \" \" & $path);",
          "else") ++ ind(adaLeaf(p.dataType, l, buf, path)) ++ List("end if;"))
        if (p.cond.ifExpr.isDefined) List(s"if $has ($obj) then") ++ ind(leaf) ++ List("else") ++ ind(absent) ++ List("end if;")
        else leaf
    }
  }

  private def adaRepeat(cs: ClassSpec, a: AttrSpec, obj: String, buf: String, path: String): List[String] = {
    val pkg = pkgOf(cs)
    val bs = cc.memberBase(a.id)
    val mname = cc.memberName(cs, a.id)
    if (AdaTranslator.hasProcess(a.dataType)) skip("a repeated field with `process`")
    val i = nm("I")
    val fixed = AdaTranslator.fixedElement(a.dataType).isDefined
    val ix = if (fixed) s"($i - 1)" else i
    val elemPath = s"$path & \"[\" & Img ($ix) & \"]\""
    val head = List(s"Put_U ($path & \".size\", ${KT}U64 ($pkg.${bs}_Count ($obj)));")
    val dt = a.dataType
    val loop: List[String] = AdaTranslator.fixedElement(dt) match {
      case Some(_) =>
        val code = dt match {
          case FloatMultiType(_, _) => s"$pkg.${bs}_Bits ($obj, $buf, $ix)"
          case _ => s"$pkg.$mname ($obj, $buf, $ix)"
        }
        val leafDt = dt match { case et: EnumType => et.basedOn; case other => other }
        List(s"for $i in 1 .. $pkg.${bs}_Count ($obj) loop") ++ ind(
          List("exit when Failed;") ++ adaLeaf(leafDt, code, buf, elemPath)) ++ List("end loop;")
      case None =>
        val pos = nm("Pos")
        val e = nm("E")
        blk(List(s"$pos : $pkg.${bs}_Cursor := $pkg.${bs}_First ($obj);", s"$i : ${KT}Length := 0;", s"$e : ${storedAda(dt)};"), List(
          s"if not $pkg.Belongs_To ($pos, $buf) then",
          s"   Fail (\"cursor \" & $path);",
          "else",
          s"   while $pkg.Has_Element ($pos) and then not Failed loop") ++ ind(List(
            s"$pkg.Next ($obj, $buf, $pos, $e);") ++ adaLeaf(dt, e, buf, elemPath) ++ List(s"$i := $i + 1;"), 2) ++ List(
          "   end loop;",
          s"   if not Failed and then $i /= $pkg.${bs}_Count ($obj) then",
          s"      Fail (\"count \" & $path);",
          "   end if;",
          "end if;"))
    }
    head ++ loop
  }

  private def adaSwitch(cs: ClassSpec, a: AttrSpec, st: SwitchType, obj: String, buf: String, path: String): List[String] = {
    val pkg = pkgOf(cs)
    val bs = cc.memberBase(a.id)
    val mname = cc.memberName(cs, a.id)
    if (st.cases.values.forall(isIntCase)) {
      val ada = try cc.switchIntType(st) catch { case u: AdaUnsupported => skip(u.getMessage) }
      val signed = ada.startsWith("S")
      val leaf = if (signed) List(s"Put_S ($path, ${KT}S64 ($pkg.$mname ($obj)));") else List(s"Put_U ($path, ${KT}U64 ($pkg.$mname ($obj)));")
      if (a.cond.ifExpr.isEmpty && !st.hasElseCase)
        List(s"if $pkg.${cc.presenceName(cs, a.id)} ($obj) then") ++ ind(leaf) ++ List("else", s"   Put_Absent ($path);", "end if;")
      else leaf
    } else {
      val vs = try cc.switchVariants(st) catch { case u: AdaUnsupported => skip(u.getMessage) }
      val arms = vs.flatMap { case (dt, n) =>
        val code = s"$pkg.${bs}_As_$n ($obj)"
        List(s"when $pkg.${bs}_Is_$n =>", s"   Put_Line ($path & \".case\", \"$n\");") ++ ind(adaLeaf(dt, code, buf, path))
      }
      List(s"case $pkg.${bs}_Case ($obj) is") ++ ind(arms ++ List(s"when $pkg.${bs}_Is_None =>", "   Put_Absent (" + path + ");")) ++ List("end case;")
    }
  }

  private def adaProcessed(cs: ClassSpec, a: AttrSpec, dt: DataType, obj: String, buf: String, path: String): List[String] = {
    val pkg = pkgOf(cs)
    val mname = cc.memberName(cs, a.id)
    // the result of zlib is larger than the input, and a custom process may do what it likes
    val zlib = dt match {
      case b: BytesType => b.process.exists(p => p == ProcessZlib || p.isInstanceOf[ProcessCustom])
      case ut: UserTypeFromBytes => ut.process.exists(p => p == ProcessZlib || p.isInstanceOf[ProcessCustom])
      case _ => false
    }
    val work = nm("Work")
    val o = nm("Outcome")
    val size = if (zlib) s"$buf'Length * 256 + 4096" else s"$buf'Length + 1"
    val decls = List(s"$work : Buffer_Access := new ${KT}Bytes (1 .. $size);", s"$o : ${KT}Status_Kind;")
    val fail = List(s"Fail (\"outcome \" & ${KT}Status_Kind'Image ($o) & \" \" & $path);")
    dt match {
      case _: BytesType =>
        val last = nm("Last")
        val sl = nm("Item")
        blk(decls ++ List(s"$last : ${KT}Length;"), List(
          s"$pkg.$mname ($obj, $buf, $work.all, $last, $o);",
          s"if $o /= ${KT}Success then") ++ ind(fail) ++ List(
          "else",
          s"   Put_Hex ($path, $work.all, (First => $work.all'First, Last => $last));",
          "end if;",
          s"Free ($work);"))
      case ut: UserTypeFromBytes =>
        val l = nm("L")
        val cs2 = ut.classSpec.get
        blk(decls ++ List(s"$l : ${pkgOf(cs2)}.T;"), List(
          s"$pkg.$mname ($obj, $buf, $work.all, $l, $o);",
          s"if $o /= ${KT}Success then") ++ ind(fail) ++ List("else") ++
          ind(adaLeaf(ut, l, s"$work.all", path)) ++ List("end if;", s"Free ($work);"))
      case other => skip(s"process on $other")
    }
  }

  private def adaProc(cs: ClassSpec): List[String] = {
    val p = procOf(cs)
    val pkg = pkgOf(cs)
    withs += cc.base(cs.name.head)
    val belongs = if (cc.hasBelongs(cs)) List(
      s"if not $pkg.Belongs_To (This, Buffer) then",
      "   Fail (\"belongs \" & Path);",
      "   return;",
      "end if;") else Nil
    val ms = members(cs)
    val body = ms.flatMap(m => adaMember(cs, m, "This", "Buffer", s"Path & \".${idStr(m.id)}\""))
    val unused = if (ms.isEmpty) List("pragma Unreferenced (Buffer, This, Path);") else Nil
    List(s"procedure Dump_$p (Buffer : ${KT}Bytes; This : $pkg.T; Path : String) is") ++ ind(unused) ++
      List("begin") ++ ind(if (ms.isEmpty) List("null;") else belongs ++ body) ++ List(s"end Dump_$p;", "")
  }

  // ---------------------------------------------------------------- Python

  private def pyLeaf(dt: DataType, enc: String, v: String, path: String): List[String] = dt match {
    case _: BooleanType | _: IntType | _: EnumType => List(s"put_int($path, $v)")
    case FloatMultiType(w, _) => List(s"put_float($path, $v, '${if (w.width == 4) "f" else "d"}')")
    case CalcFloatType => List(s"put_float($path, $v, 'd')")
    case _: BytesType => List(s"put_bytes($path, $v)")
    case _: StrType => List(s"put_str($path, $v, ${pyLit(enc)})")
    case ut: UserType if ut.classSpec.get.meta.isOpaque => skip(s"the opaque type ${ut.classSpec.get.nameAsStr}, whose members are not known")
    case ut: UserType =>
      val p = procOf(ut.classSpec.get)
      List(s"if $v is None:", s"   put_absent($path)", "else:", s"   dump_$p($v, $path)")
    case other => skip(s"value of type $other")
  }

  private def pyMember(cs: ClassSpec, m: MemberSpec, obj: String, path: String): List[String] = {
    val attr = pyAttr(m.id)
    val v = nm("v")
    m match {
      case a: AttrSpec if a.cond.repeat != NoRepeat =>
        val dt = a.dataType
        val e = nm("e")
        val i = nm("i")
        val enc = encodingOf(cs, m, dt)
        List(s"$v = $obj.$attr", s"put_int($path + '.size', len($v))", s"for $i, $e in enumerate($v):") ++
          ind(pyLeaf(dt, enc, e, s"$path + '[' + str($i) + ']'"))
      case a: AttrSpec if a.dataType.isInstanceOf[SwitchType] =>
        val st = a.dataType.asInstanceOf[SwitchType]
        if (st.cases.values.forall(isIntCase))
          List(s"$v = getattr($obj, '$attr', None)", s"put_int($path, $v)")
        else {
          val vs = cc.switchVariants(st)
          val arms = vs.map { case (dt, n) =>
            val test = dt match {
              case ut: UserType => s"type($v).__qualname__ == '${pyClassName(ut.classSpec.get)}'"
              case _: BytesType => s"isinstance($v, bytes)"
              case _ => s"isinstance($v, str)"
            }
            (test, List(s"put_line($path + '.case', '$n')") ++ pyLeaf(dt, encodingOf(cs, m, dt), v, path))
          }
          List(s"$v = getattr($obj, '$attr', None)", s"if $v is None:", s"   put_absent($path)") ++
            arms.flatMap { case (t, body) => List(s"elif $t:") ++ ind(body) } ++
            List("else:", s"   raise AssertionError('unexpected case ' + type($v).__qualname__)")
        }
      case a: AttrSpec =>
        // a field with `if` is not set at all if the condition does not hold
        val get = if (a.cond.ifExpr.isDefined) s"getattr($obj, '$attr', None)" else s"$obj.$attr"
        List(s"$v = $get") ++ pyLeaf(a.dataType, encodingOf(cs, m, a.dataType), v, path)
      case p: ParamDefSpec =>
        List(s"$v = $obj.$attr") ++ pyLeaf(p.dataType, "UTF-8", v, path)
      case vi: ValueInstanceSpec =>
        // an instance of float type is an F64 in Ada, whatever width the type of the expression has in the compiler
        val vdt = vi.dataType match { case _: FloatType => CalcFloatType; case other => other }
        List(s"$v = $obj.$attr") ++ pyLeaf(vdt, encodingOf(cs, m, vi.dataType), v, path)
      case pi: ParseInstanceSpec =>
        List(s"$v = $obj.$attr") ++ pyLeaf(pi.dataType, encodingOf(cs, m, pi.dataType), v, path)
    }
  }

  private def pyProc(cs: ClassSpec): List[String] = {
    val p = procOf(cs)
    val ms = members(cs)
    val body = ms.flatMap(m => pyMember(cs, m, "o", s"p + '.${idStr(m.id)}'"))
    List(s"def dump_$p(o, p):") ++ ind(if (body.isEmpty) List("pass") else body) ++ List("")
  }

  // ------------------------------------------------------------------ main

  def run(): Unit = {
    if (top.params.nonEmpty) skip("the top-level type has parameters")
    val topId = procOf(top)
    withs += cc.base(top.name.head)
    val adaProcs = ListBuffer[(Int, List[String])]()
    val pyProcs = ListBuffer[List[String]]()
    while (queue.nonEmpty) {
      val cs = queue.dequeue()
      adaProcs += ((procOf(cs), adaProc(cs)))
      pyProcs += pyProc(cs)
    }
    val topPkg = pkgOf(top)
    val recursiveTop = top.seq.exists(a => containsSelf(a.dataType)) ||
      top.instances.values.exists { case pi: ParseInstanceSpec => containsSelf(pi.dataType); case _ => false }
    val parseArgs = if (recursiveTop) s", $topPkg.Max_Depth" else ""

    val sb = new StringBuilder
    def p(s: String): Unit = sb.append(s).append("\n")
    p("--  Generated by AdaDiff (compiler/tests-overlay); the dump of scripts/diff-python.sh")
    p("with Ada.Command_Line;")
    p("with Ada.Exceptions;")
    p("with Ada.Strings.Unbounded;")
    p("with Ada.Text_IO;")
    p("with Ada.Unchecked_Conversion;")
    p("with Ada.Unchecked_Deallocation;")
    p("with Kaitai.Files;")
    p("with Kaitai.Floats;")
    p("with Kaitai.Streams;")
    p("with Kaitai.Types;")
    withs.toList.sorted.foreach(w => p(s"with $w;"))
    p("")
    p(s"procedure Dump_${cc.base(name)} is")
    p("   use type Kaitai.Types.Length;")
    p("   use type Kaitai.Types.U8;")
    p("   use type Kaitai.Types.U64;")
    p("   use type Kaitai.Types.S64;")
    p("   use type Kaitai.Types.Status_Kind;")
    p("")
    p("   package U renames Ada.Strings.Unbounded;")
    p("   type Buffer_Access is access Kaitai.Types.Bytes;")
    p("   procedure Free is new Ada.Unchecked_Deallocation (Kaitai.Types.Bytes, Buffer_Access);")
    p("")
    p("   Output : U.Unbounded_String;")
    p("   Failed : Boolean := False;")
    p("   Why    : U.Unbounded_String;")
    p("   LF     : constant Character := Character'Val (10);")
    p("   --  a dump larger than this is not compared: both sides give up at the same line")
    p("   Dump_Limit : constant := 8_000_000;")
    p("")
    p("   function Img (N : Kaitai.Types.Length) return String is")
    p("      Image : constant String := Kaitai.Types.Length'Image (N);")
    p("   begin")
    p("      return Image (Image'First + 1 .. Image'Last);")
    p("   end Img;")
    p("")
    p("   procedure Fail (Reason : String) is")
    p("   begin")
    p("      if not Failed then")
    p("         Failed := True;")
    p("         Why := U.To_Unbounded_String (Reason);")
    p("      end if;")
    p("   end Fail;")
    p("")
    p("   procedure Put_Line (Path : String; Value : String) is")
    p("   begin")
    p("      if not Failed then")
    p("         U.Append (Output, Path & \" = \" & Value & LF);")
    p("         if U.Length (Output) > Dump_Limit then")
    p("            Fail (\"dump too large\");")
    p("         end if;")
    p("      end if;")
    p("   end Put_Line;")
    p("")
    p("   procedure Put_Absent (Path : String) is")
    p("   begin")
    p("      Put_Line (Path, \"absent\");")
    p("   end Put_Absent;")
    p("")
    p("   procedure Put_Bool (Path : String; Value : Boolean) is")
    p("   begin")
    p("      Put_Line (Path, (if Value then \"1\" else \"0\"));")
    p("   end Put_Bool;")
    p("")
    p("   procedure Put_U (Path : String; Value : Kaitai.Types.U64) is")
    p("      Image : constant String := Kaitai.Types.U64'Image (Value);")
    p("   begin")
    p("      Put_Line (Path, Image (Image'First + 1 .. Image'Last));")
    p("   end Put_U;")
    p("")
    p("   procedure Put_S (Path : String; Value : Kaitai.Types.S64) is")
    p("      Image : constant String := Kaitai.Types.S64'Image (Value);")
    p("   begin")
    p("      Put_Line (Path, (if Value < 0 then Image else Image (Image'First + 1 .. Image'Last)));")
    p("   end Put_S;")
    p("")
    p("   Digits_Hex : constant String := \"0123456789abcdef\";")
    p("")
    p("   function Hex (Value : Kaitai.Types.U64; Width : Positive) return String is")
    p("      Result : String (1 .. Width);")
    p("      V      : Kaitai.Types.U64 := Value;")
    p("   begin")
    p("      for I in reverse Result'Range loop")
    p("         Result (I) := Digits_Hex (Digits_Hex'First + Natural (V mod 16));")
    p("         V := V / 16;")
    p("      end loop;")
    p("      return Result;")
    p("   end Hex;")
    p("")
    p("   procedure Put_Float4 (Path : String; Bits : Kaitai.Types.U32) is")
    p("      use type Kaitai.Types.U32;")
    p("   begin")
    p("      if (Bits and 16#7F80_0000#) = 16#7F80_0000# and then (Bits and 16#7F_FFFF#) /= 0 then")
    p("         Put_Line (Path, \"nan\");")
    p("      else")
    p("         Put_Line (Path, Hex (Kaitai.Types.U64 (Bits), 8));")
    p("      end if;")
    p("   end Put_Float4;")
    p("")
    p("   procedure Put_Float8 (Path : String; Bits : Kaitai.Types.U64) is")
    p("   begin")
    p("      if (Bits and 16#7FF0_0000_0000_0000#) = 16#7FF0_0000_0000_0000# and then (Bits and 16#F_FFFF_FFFF_FFFF#) /= 0 then")
    p("         Put_Line (Path, \"nan\");")
    p("      else")
    p("         Put_Line (Path, Hex (Bits, 16));")
    p("      end if;")
    p("   end Put_Float8;")
    p("")
    p("   function Bits_Of is new Ada.Unchecked_Conversion (Kaitai.Floats.F64, Kaitai.Types.U64);")
    p("")
    p("   --  the value of an instance: a finite number, printed as its bits, as Python prints a float")
    p("   procedure Put_Double (Path : String; Value : Kaitai.Floats.F64) is")
    p("   begin")
    p("      Put_Float8 (Path, Bits_Of (Value));")
    p("   end Put_Double;")
    p("")
    p("   procedure Put_Hex (Path : String; Buffer : Kaitai.Types.Bytes; Item : Kaitai.Types.Slice) is")
    p("   begin")
    p("      if Failed then")
    p("         return;")
    p("      elsif not Kaitai.Types.Within (Item, Buffer) then")
    p("         Fail (\"slice outside the buffer \" & Path);")
    p("      elsif Kaitai.Types.Is_Empty (Item) then")
    p("         Put_Line (Path, \"\");")
    p("      else")
    p("         declare")
    p("            Text : String (1 .. Natural (Kaitai.Types.Size (Item)) * 2);")
    p("            K    : Natural := 0;")
    p("         begin")
    p("            for I in Item.First .. Item.Last loop")
    p("               Text (2 * K + 1) := Digits_Hex (Digits_Hex'First + Natural (Buffer (I) / 16));")
    p("               Text (2 * K + 2) := Digits_Hex (Digits_Hex'First + Natural (Buffer (I) mod 16));")
    p("               K := K + 1;")
    p("            end loop;")
    p("            Put_Line (Path, Text);")
    p("         end;")
    p("      end if;")
    p("   end Put_Hex;")
    p("")
    adaProcs.foreach { case (n, _) =>
      val cs = classes.values.find(c => procOf(c) == n).get
      p(s"   procedure Dump_$n (Buffer : ${KT}Bytes; This : ${pkgOf(cs)}.T; Path : String);")
    }
    p("")
    adaProcs.foreach { case (_, ls) => ls.foreach(l => p(if (l.isEmpty) "" else "   " + l)) }
    p("begin")
    p("   for A in 1 .. Ada.Command_Line.Argument_Count loop")
    p("      declare")
    p("         File : constant String := Ada.Command_Line.Argument (A);")
    p("         Size : Kaitai.Types.Length;")
    p("         Last : Kaitai.Types.Length;")
    p("         Result : Kaitai.Files.Result_Kind;")
    p("         Buffer : Buffer_Access := null;")
    p("      begin")
    p("         Output := U.Null_Unbounded_String;")
    p("         Why := U.Null_Unbounded_String;")
    p("         Failed := False;")
    p("         Ada.Text_IO.Put_Line (\"@@ \" & File);")
    p("         Kaitai.Files.Get_Size (File, Size, Result);")
    p("         if Result not in Kaitai.Files.Done then")
    p("            Ada.Text_IO.Put_Line (\"EXCEPTION cannot read the file\");")
    p("         else")
    p("            Buffer := new Kaitai.Types.Bytes (1 .. Size);")
    p("            Kaitai.Files.Read (File, Buffer.all, Last, Result);")
    p("            declare")
    p("               S : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer.all);")
    p(s"               R : $topPkg.T;")
    p("            begin")
    p(s"               $topPkg.Parse (R, Buffer.all, S$parseArgs);")
    p(s"               if not $topPkg.Valid (R) then")
    p("                  Fail (\"parse \" & Kaitai.Types.Status_Kind'Image (Kaitai.Streams.Status (S)));")
    p("               else")
    p(s"                  Dump_$topId (Buffer.all, R, \"r\");")
    p("               end if;")
    p("            end;")
    p("            if Failed then")
    p("               Ada.Text_IO.Put_Line (\"FAILED\");")
    p("               Ada.Text_IO.Put_Line (\"#why \" & U.To_String (Why));")
    p("            else")
    p("               Ada.Text_IO.Put (U.To_String (Output));")
    p("            end if;")
    p("            Free (Buffer);")
    p("         end if;")
    p("      exception")
    p("         when E : others =>")
    p("            Ada.Text_IO.Put_Line (\"EXCEPTION \" & Ada.Exceptions.Exception_Name (E));")
    p("            Ada.Text_IO.Put_Line (\"#why \" & Ada.Exceptions.Exception_Message (E));")
    p("      end;")
    p("   end loop;")
    p(s"end Dump_${cc.base(name)};")
    adaText = sb.toString

    val py = new StringBuilder
    def q(s: String): Unit = py.append(s).append("\n")
    q("# Generated by AdaDiff (compiler/tests-overlay); the dump of scripts/diff-python.sh")
    q("import gc")
    q("import struct")
    q("import sys")
    q("import traceback")
    q("")
    q("sys.setrecursionlimit(100000)")
    q("sys.path.insert(0, sys.argv[1])")
    q(s"import ${top.name.head}")
    q("")
    q("out = []")
    q("size = [0]")
    q("DUMP_LIMIT = 8000000  # a dump larger than this is not compared: both sides give up at the same line")
    q("")
    q("def put_line(path, value):")
    q("    out.append(path + ' = ' + value)")
    q("    size[0] += len(path) + len(value) + 4")
    q("    if size[0] > DUMP_LIMIT:")
    q("        raise OverflowError('dump too large')")
    q("")
    q("def put_absent(path):")
    q("    put_line(path, 'absent')")
    q("")
    q("def put_int(path, v):")
    q("    if v is None:")
    q("        put_absent(path)")
    q("    else:")
    q("        put_line(path, str(int(v)))")
    q("")
    q("def put_float(path, v, kind):")
    q("    if v is None:")
    q("        put_absent(path)")
    q("    elif v != v:")
    q("        put_line(path, 'nan')")
    q("    else:")
    q("        put_line(path, struct.pack('>' + kind, v).hex())")
    q("")
    q("def put_bytes(path, v):")
    q("    if v is None:")
    q("        put_absent(path)")
    q("    else:")
    q("        put_line(path, bytes(v).hex())")
    q("")
    q("def put_str(path, v, enc):")
    q("    if v is None:")
    q("        put_absent(path)")
    q("    else:")
    q("        put_line(path, v.encode(enc).hex())")
    q("")
    pyProcs.foreach(ls => ls.foreach(q))
    q("def main():")
    q("    for f in sys.argv[2:]:")
    q("        out.clear()")
    q("        r = None")
    q("        gc.collect()  # a value with billions of elements must not take the memory of the next input")
    q("        size[0] = 0")
    q("        why = None")
    q("        try:")
    q("            with open(f, 'rb') as fh:")
    q("                data = fh.read()")
    q(s"            r = ${top.name.head}.${pyClassName(top)}.from_bytes(data)")
    q("            if hasattr(r, '_debug'):")
    q("                r._read()  # a parser generated with ks-debug does not read in the constructor")
    q(s"            dump_$topId(r, 'r')")
    q("        except Exception as e:")
    q("            why = 'dump too large' if str(e) == 'dump too large' else type(e).__name__ + ': ' + str(e).replace('\\n', ' ')[:200]")
    q("        print('@@ ' + f)")
    q("        if why is not None:")
    q("            print('FAILED')")
    q("            print('#why ' + why)")
    q("        elif out:")
    q("            print('\\n'.join(out))")
    q("")
    q("main()")
    pyText = py.toString
  }

  /** The data type is, or chooses among, the type of the top-level class itself */
  private def containsSelf(dt: DataType): Boolean = dt match {
    case ut: UserType => ut.classSpec.exists(_ eq top)
    case st: SwitchType => st.cases.values.exists(containsSelf)
    case _ => false
  }
}
