package io.kaitai.struct

import io.kaitai.struct.datatype.DataType._
import io.kaitai.struct.datatype._
import io.kaitai.struct.exprlang.Ast
import io.kaitai.struct.format._
import io.kaitai.struct.languages.components.{LanguageCompiler, LanguageCompilerStatic}
import io.kaitai.struct.problems.KSYParseError
import io.kaitai.struct.translators._

import scala.collection.mutable
import scala.collection.mutable.ListBuffer

/**
  * Generates an Ada/SPARK parser, as two files `<id>.ads` and `<id>.adb`,
  * following the rules of docs/codegen.md of the Kaitai Struct Ada runtime.
  * It walks the class tree itself instead of using the callbacks of
  * [[LanguageCompiler]].
  */
class AdaClassCompiler(classSpecs: ClassSpecs, topClass: ClassSpec, config: RuntimeConfig) extends AbstractCompiler with AdaTranslatorEnv {
  import AdaClassCompiler._

  val provider = new ClassTypeProvider(classSpecs, topClass)
  val tr = new AdaTranslator(provider, this)

  // ------------------------------------------------------------------ errors

  private def fail(path: List[String], msg: String): Nothing =
    throw KSYParseError.withText(s"not supported by the Ada backend: $msg", path)

  private def guard[A](path: List[String])(f: => A): A =
    try f catch {
      case u: AdaUnsupported => fail(path, u.getMessage)
    }

  // ------------------------------------------------------------------- names

  def base(raw: String): String = {
    val parts = raw.split("_+").filter(_.nonEmpty).map(w => w.head.toUpper + w.tail)
    val n = parts.mkString("_")
    if (n.isEmpty) "X" else if (n.head.isDigit) "N" + n else n
  }

  /** The names of the packages of other descriptions, which a name of the description must not take */
  private lazy val importedNames: Set[String] =
    classSpecs.keys.map(k => base(k).toLowerCase).toSet ++ foreignRoots.map(_.toLowerCase)

  private def isReserved(n: String): Boolean =
    Reserved.contains(n.toLowerCase) || n.toLowerCase == topAdaName.toLowerCase || importedNames.contains(n.toLowerCase)

  private def plain(raw: String): String = plainIn(provider.nowClass, raw)

  private def plainIn(cs: ClassSpec, raw: String): String = {
    val b = base(raw)
    if (isReserved(b) || raw.endsWith("_") || raw.contains("__") || derivedNames(cs).contains(b.toLowerCase) || b.toLowerCase.startsWith("eval_")) b + "_Field"
    else b
  }

  private val derivedMemo = mutable.Map[String, Set[String]]()

  /** Names that the generated code derives in the declarative region of a type; an identifier of the description must not equal one. */
  private def derivedNames(cs: ClassSpec): Set[String] = derivedMemo.getOrElseUpdate(cs.nameAsStr, {
    val out = mutable.Set[String]()
    def memberNames(id: Identifier, dt: DataType, isInstance: Boolean): Unit = {
      val b = base(idRaw(id))
      List("Has_", "Get_", "Parse_").foreach(pre => out += (pre + b).toLowerCase)
      List("_count", "_first", "_cursor", "_value", "_bits", "_case", "_kind", "_variant", "_expected", "_io", "_is_none", "_raw")
        .foreach(suf => out += (b + suf).toLowerCase)
      out += s"parse_${b}_element".toLowerCase
      out += s"${b}_first_element".toLowerCase
      out += s"${b}_last_element".toLowerCase
      keptElems(cs).getOrElse(b, Nil).filter(_ > 0).foreach(k => out += s"${b}_element_$k".toLowerCase)
      dt match {
        case st: SwitchType =>
          st.cases.values.foreach {
            case ut: UserType =>
              val y = variantBase(ut.classSpec.get)
              out += s"${b}_as_$y".toLowerCase
              out += s"${b}_is_$y".toLowerCase
            case _ =>
              List("bytes", "str").foreach { y => out += s"${b}_as_$y".toLowerCase; out += s"${b}_is_$y".toLowerCase }
          }
        case _ =>
      }
    }
    cs.params.foreach(p => memberNames(p.id, p.dataType, false))
    cs.seq.foreach(a => memberNames(a.id, a.dataType, false))
    cs.instances.foreach { case (id, i) => memberNames(id, i.dataType, true) }
    cs.types.keys.foreach(t => out += (base(t) + "_type").toLowerCase)
    refsOf(cs).foreach(r => out += r.adaName.toLowerCase)
    if (isRecursive(cs)) out += "depth"
    cs.enums.foreach { case (n, e) =>
      val en = base(n) + "_Enum"
      out += en.toLowerCase; out += s"is_$en".toLowerCase; out += s"to_$en".toLowerCase; out += "to_integer"
      e.map.values.foreach(v => out += s"${base(n)}_${base(v.name)}".toLowerCase)
    }
    out.toSet
  })

  private def paramName(raw: String): String = {
    val b = plain(raw)
    if (ParamReserved.contains(b.toLowerCase)) b + "_Field" else b
  }

  private def idRaw(id: Identifier): String = id match {
    case NamedIdentifier(n) => n
    case InstanceIdentifier(n) => n
    case NumberedIdentifier(i) => s"unnamed_$i"
    case SpecialIdentifier(n) => n.stripPrefix("_")
    case other => other.humanReadable.stripPrefix("_")
  }

  override def memberName(cs: ClassSpec, id: Identifier): String = plainIn(cs, idRaw(id))
  override def memberBase(id: Identifier): String = base(idRaw(id))

  /** Name of the function (and component) that tells whether a member exists: `Has_X`, unless a member has that name. */
  private def hasNmIn(cs: ClassSpec, bs: String): String = {
    s"Has_$bs"
  }
  private def hasNm(bs: String): String = hasNmIn(provider.nowClass, bs)
  override def presenceName(cs: ClassSpec, id: Identifier): String = hasNmIn(cs, base(idRaw(id)))

  private lazy val topAdaName: String = base(topClass.name.head)

  private def typePkg(name: String): String = base(name) + "_Type"

  /** The package of a type: nested in the package of the description, or a package of another description */
  override def packageOf(cs: ClassSpec): String =
    if (cs.name.head == topClass.name.head) cs.name.tail.map(typePkg).mkString(".")
    else fullPackageOf(cs)

  /** The full name of the package of a type, also for the top-level type of the description being compiled */
  def fullPackageOf(cs: ClassSpec): String = (base(cs.name.head) :: cs.name.tail.map(typePkg)).mkString(".")

  private def enumLit(spec: EnumSpec, label: String): String = s"${base(spec.name.last)}_${base(label)}"
  private def enumTy(spec: EnumSpec): String = s"${base(spec.name.last)}_Enum"

  override def enumTypeName(spec: EnumSpec): String = {
    val owner = spec.name.dropRight(1)
    val prefix =
      if (owner.head != topClass.name.head) (base(owner.head) :: owner.tail.map(typePkg)).mkString(".") + "."
      else if (owner.size <= 1) ""
      else owner.tail.map(typePkg).mkString(".") + "."
    prefix + enumTy(spec)
  }

  override def encodingName(enc: String, path: List[String]): String = enc.toUpperCase match {
    case "ASCII" | "US-ASCII" => "Kaitai.Strings.US_ASCII"
    case "UTF-8" => "Kaitai.Strings.UTF_8"
    case "UTF-16LE" => "Kaitai.Strings.UTF_16LE"
    case "UTF-16BE" => "Kaitai.Strings.UTF_16BE"
    case e if e.startsWith("UTF-16") || e.startsWith("UTF-32") || e.startsWith("UCS") || e.startsWith("UTF-7") =>
      throw new AdaUnsupported(s"encoding $enc")
    case _ if !EncodingList.canonicalSet.contains(enc) =>
      // Without this a misspelt name would be taken for an encoding of one byte per character, which accepts everything.
      throw new AdaUnsupported(s"encoding `$enc`, which is not one that Kaitai Struct knows")
    case _ => "Kaitai.Strings.Single_Byte"
  }

  private def isContents(a: AttrLikeSpec): Boolean = a match {
    case at: AttrSpec =>
      at.cond.repeat == NoRepeat && (at.dataType match {
        case BytesLimitType(Ast.expr.IntNum(n), None, false, None, None) =>
          at.valid match {
            case Some(ValidationEq(Ast.expr.List(elts))) =>
              elts.size == n && elts.forall(_.isInstanceOf[Ast.expr.IntNum])
            case _ => false
          }
        case _ => false
      })
    case _ => false
  }

  override def isStored(attr: AttrLikeSpec): Boolean = !isContents(attr)

  // ------------------------------------------------------ value instance info

  private val instInfo = mutable.Map[(String, String), (Boolean, Boolean)]()

  /** A value instance that is an integer literal above the largest S64 (and below 2**64): it is a U64, and nothing else uses it */
  private def bigLiteral(v: ValueInstanceSpec): Option[BigInt] = v.value match {
    case Ast.expr.IntNum(n) if n > AdaTranslator.S64Max && n <= AdaTranslator.U64Max && v.ifExpr.isEmpty => Some(n)
    case _ => None
  }

  override def valueInstanceIsU64(cs: ClassSpec, inst: ValueInstanceSpec): Boolean = bigLiteral(inst).isDefined

  private def valueInfo(cs: ClassSpec, v: ValueInstanceSpec): (Boolean, Boolean) =
    if (bigLiteral(v).isDefined) (false, false) else instInfo.getOrElseUpdate((cs.nameAsStr, v.id.name), {
      val saved = provider.nowClass
      provider.nowClass = cs
      try {
        val t2 = new AdaTranslator(provider, this)
        val t = guard(v.path)(t2.translate(v.value))
        var guards = t.guards
        var ub = t.usesBuffer
        v.ifExpr.foreach { c =>
          val ct = guard(v.path)(t2.translate(c))
          guards = ct.guards ++ guards
          ub = ub || ct.usesBuffer
        }
        val isSlice = v.dataType match {
          case _: BytesType | _: StrType => true
          case ut: UserType => ut.classSpec.exists(hasBelongs)
          case _ => false
        }
        (v.ifExpr.isDefined || guards.nonEmpty, ub || isSlice)
      } finally provider.nowClass = saved
    })

  override def valueInstanceHasGuard(cs: ClassSpec, inst: ValueInstanceSpec): Boolean = valueInfo(cs, inst)._1
  override def valueInstanceUsesBuffer(cs: ClassSpec, inst: ValueInstanceSpec): Boolean = valueInfo(cs, inst)._2

  // ------------------------------------------------------------ class analysis

  private def userTypesOf(cs: ClassSpec): List[ClassSpec] = {
    def ofType(dt: DataType): List[ClassSpec] = dt match {
      case ut: UserType => ut.classSpec.toList
      case st: SwitchType => st.cases.values.toList.flatMap(ofType)
      case _ => Nil
    }
    cs.seq.flatMap(a => ofType(a.dataType)) ++ cs.params.flatMap(p => ofType(p.dataType)) ++
      cs.instances.values.toList.flatMap {
        case p: ParseInstanceSpec => ofType(p.dataType)
        case _ => Nil
      }
  }

  /** All classes of the compilation: the nested types, the types that they use, also those of imported descriptions. */
  private lazy val allClasses: List[ClassSpec] = {
    val seen = ListBuffer[ClassSpec]()
    def visit(c: ClassSpec): Unit =
      if (!seen.exists(_ eq c)) {
        seen += c
        c.types.values.foreach(visit)
        userTypesOf(c).foreach(visit)
      }
    visit(topClass)
    seen.toList
  }

  // ------------------------------------------------------------ foreign code

  /** The processes of a field, whatever its type: a field of bytes, a string, a type or a case of a switch */
  private def processesOf(dt: DataType): List[ProcessExpr] = dt match {
    case b: BytesType => b.process.toList
    case StrFromBytesType(b, _, _) => b.process.toList
    case ut: UserTypeFromBytes => ut.process.toList
    case st: SwitchType => st.cases.values.toList.flatMap(processesOf)
    case _ => Nil
  }

  private def attrsOf(cs: ClassSpec): List[AttrLikeSpec] =
    cs.seq ++ cs.instances.values.toList.collect { case p: ParseInstanceSpec => p }

  /** The packages that hand-written code provides: the opaque types and the custom processes, by their full names */
  private lazy val foreignPackages: List[String] = foreignPackagesOf(allClasses)

  /** The foreign packages that the given classes call: those of their opaque types and custom processes */
  private def foreignPackagesOf(classes: List[ClassSpec]): List[String] = {
    val procs = classes.filter(c => !c.meta.isOpaque).flatMap(c => attrsOf(c).flatMap(a => processesOf(a.dataType))).collect {
      case ProcessCustom(name, _) => name.map(base).mkString(".")
    }
    val types = classes.filter(c => !c.meta.isOpaque).flatMap(c => attrsOf(c).flatMap(a => opaqueOf(a.dataType))).map(fullPackageOf)
    (types ++ procs).distinct.sorted
  }

  private def opaqueOf(dt: DataType): List[ClassSpec] = dt match {
    case ut: UserType => ut.classSpec.filter(_.meta.isOpaque).toList
    case st: SwitchType => st.cases.values.toList.flatMap(opaqueOf)
    case _ => Nil
  }

  /** The first names of those packages, which no name of the generated code may take */
  private lazy val foreignRoots: Set[String] = foreignPackages.map(_.takeWhile(_ != '.')).toSet

  /**
    * The name of the package of an opaque type or a custom process, written from the names of the description. A
    * name that Ada cannot use for a package, or that the generated code uses itself, is an error: the description
    * would have to be changed.
    */
  private def foreignName(names: List[String], what: String): String = {
    val parts = names.map(base)
    parts.zip(names).foreach { case (b, raw) =>
      val l = b.toLowerCase
      if (Reserved.contains(l) || LibPackages.exists(_.toLowerCase == l) || l == topAdaName.toLowerCase || classSpecs.keys.exists(k => base(k).toLowerCase == l) ||
          raw.contains("__") || raw.endsWith("_"))
        unsupported(s"$what `${names.mkString(".")}`: its name `$raw` is not usable as the name of a package (a reserved word of Ada, a name that the generated code uses, or the name of a description)")
    }
    parts.mkString(".")
  }

  private def processPackage(name: List[String]): String = foreignName(name, "custom `process:`")

  /** The opaque types and custom processes of the compilation are ones that the backend can generate calls for. */
  private def checkForeign(): Unit =
    allClasses.filterNot(_.meta.isOpaque).foreach { c =>
      attrsOf(c).foreach { a =>
        guard(a.path) {
          opaqueOf(a.dataType).foreach { o =>
            if (o.name.size != 1) unsupported(s"opaque type `${o.nameAsStr}`: only a name without `::` is supported")
            foreignName(o.name, "opaque type")
            if (config.readWrite) unsupported(s"`--read-write` for the opaque type `${o.nameAsStr}`, whose package has no `Write` in the contract")
          }
          processesOf(a.dataType).foreach { case ProcessCustom(name, _) => processPackage(name); case _ => }
        }
      }
    }

  private def reaches(from: ClassSpec, target: ClassSpec): Boolean = {
    val seen = ListBuffer[ClassSpec]()
    def go(c: ClassSpec): Boolean =
      userTypesOf(c).exists { u =>
        (u eq target) || (!seen.exists(_ eq u) && { seen += u; go(u) })
      }
    go(from)
  }

  /** The type contains itself (in a field, a repetition, or an instance). */
  private def isRecursive(cs: ClassSpec): Boolean = userTypesOf(cs).exists(_ eq cs)

  /**
    * The key `parent` gives one use of a type another parent, or none. The values of `_parent` that the type needs are
    * computed by the type that has the field from the expression of the key (see `liftExpr`); a byte order that is
    * calculated from `_parent` is not, so the key is rejected where the type of the field, or a type that it uses,
    * needs it.
    */
  private def checkParentKey(): Unit = {
    def usesParent(c: ClassSpec, seen: ListBuffer[ClassSpec]): Boolean =
      !seen.exists(_ eq c) && {
        seen += c
        (c.meta.endian match { case Some(ce: CalcEndian) => containsParent(ce.on); case _ => false }) ||
        userTypesOf(c).exists(u => usesParent(u, seen))
      }
    def forced(dt: DataType): List[ClassSpec] = dt match {
      case ut: UserType if ut.forcedParent.isDefined => ut.classSpec.toList
      case st: SwitchType => st.cases.values.toList.flatMap(forced)
      case _ => Nil
    }
    allClasses.foreach { c =>
      val attrs: List[AttrLikeSpec] = c.seq ++ c.instances.values.toList.collect { case p: ParseInstanceSpec => p }
      attrs.foreach { a =>
        forced(a.dataType).foreach { u =>
          if (usesParent(u, ListBuffer()))
            fail(c.path, s"the key `parent` on a field of type ${u.nameAsStr}, which uses `_parent`")
        }
      }
    }
  }

  /** The first field of the type is a bit field. */
  private def startsWithBits(c: ClassSpec): Boolean = c.seq.headOption.exists { a =>
    a.cond.repeat == NoRepeat && (a.dataType match {
      case _: BitsType | _: BitsType1 => true
      case EnumType(_, _, _: BitsType) => true
      case _ => false
    })
  }

  /** The types that a field reads from the stream it is in; not those read through a substream. */
  private def inStreamTypes(dt: DataType): List[ClassSpec] = dt match {
    case ut: UserTypeInstream => ut.classSpec.toList
    case st: SwitchType => st.cases.values.toList.flatMap(inStreamTypes)
    case _ => Nil
  }

  /** The field is read as whole bytes, so that the stream is at a byte boundary after it. */
  private def readsWholeBytes(a: AttrSpec): Boolean =
    a.cond.repeat == NoRepeat && a.cond.ifExpr.isEmpty && (a.dataType match {
      case _: BitsType | _: BitsType1 | EnumType(_, _, _: BitsType) => false
      case _: UserTypeInstream | _: SwitchType => false
      case _ => true
    })

  /** The classes of the descriptions that are compiled, with all that is nested in them. */
  private lazy val bitWorld: List[ClassSpec] = {
    val seen = ListBuffer[ClassSpec]()
    def visit(c: ClassSpec): Unit =
      if (!seen.exists(_ eq c)) {
        seen += c
        c.types.values.foreach(visit)
        userTypesOf(c).foreach(visit)
        c.upClass.foreach(visit)
      }
    allClasses.foreach(visit)
    seen.toList
  }

  /**
    * The types that are certainly entered at a byte boundary: the greatest set in which every use of a type in the
    * stream of another type of its own description is a field that is not repeated and either directly follows a field
    * that is read as whole bytes, or is the first field of a type of the set. The top-level type of a description counts
    * as entered at a byte boundary through its public `Parse`. A use through a substream or at a position does not
    * count, since it opens or seeks to a byte boundary.
    */
  private lazy val alignedTypes: java.util.Set[ClassSpec] = {
    val set = java.util.Collections.newSetFromMap(new java.util.IdentityHashMap[ClassSpec, java.lang.Boolean])
    bitWorld.foreach(set.add)
    val uses = for {
      c <- bitWorld
      (a, i) <- c.seq.zipWithIndex
      u <- inStreamTypes(a.dataType)
      if classFile(u) == classFile(c)
    } yield (c, a, i, u)
    var changed = true
    while (changed) {
      changed = false
      uses.foreach { case (c, a, i, u) =>
        if (set.contains(u) && !useAligned(c, a, i, u, set.contains(c))) { set.remove(u); changed = true }
      }
    }
    set
  }

  /**
    * The use of the type `u` in field `a`, the `i`th of `c`, is at a byte boundary where `c` is, or is not, entered at
    * one. A field of the own type is parsed again from the stream that was kept for it, of which nothing is known, so it
    * is not such a use.
    */
  private def useAligned(c: ClassSpec, a: AttrSpec, i: Int, u: ClassSpec, entered: Boolean): Boolean =
    !(u eq c) && a.cond.repeat == NoRepeat && (if (i == 0) entered else readsWholeBytes(c.seq(i - 1)))

  /**
    * `Parse` of the type begins with `Align_To_Byte` and has the precondition that no bits are left: the type is
    * entered at a byte boundary, and starts with a bit field or with a field of a type that has the precondition.
    * Where it is not entered at one, the bit fields go on in the byte that the bit fields before it left open, as in
    * the other targets, and `Parse` has neither.
    */
  private def needsAlign(c: ClassSpec, seen: List[ClassSpec] = Nil): Boolean =
    alignedTypes.contains(c) && !seen.exists(_ eq c) && (startsWithBits(c) || c.seq.headOption.exists { a =>
      a.cond.repeat == NoRepeat && inStreamTypes(a.dataType).exists(u => needsAlign(u, c :: seen))
    })

  /**
    * A use of a type of another description that has the precondition must be where the stream is certainly at a byte
    * boundary, since such a type is generated the same wherever it is used.
    */
  private def checkBitStart(): Unit =
    allClasses.filter(c => classFile(c) == classFile(topClass)).foreach { c =>
      c.seq.zipWithIndex.foreach { case (a, i) =>
        inStreamTypes(a.dataType).filter(u => classFile(u) != classFile(c) && needsAlign(u)).foreach { u =>
          if (!useAligned(c, a, i, u, alignedTypes.contains(c)))
            fail(c.path, s"type ${u.nameAsStr} of another description starts with a bit field and is used where the stream may be inside a byte")
        }
      }
    }

  // ------------------------------------------------------ bit order

  /*
   * The state of a stream between two reads, as far as the bit order matters: a set of the numbers 0 (at a byte
   * boundary), 1 to 7 (that many bits of a byte are left by a big-endian bit field) and 9 to 15 (8 and that many bits
   * are left by a little-endian one), kept as a mask of 16 bits.
   */
  private val BitsOfBe = 0x00FE
  private val BitsOfLe = 0xFE00
  private val BitsAny = BitsOfBe | BitsOfLe | 1

  private def bitStates(set: Int): List[Int] = (0 until 16).filter(s => (set & (1 << s)) != 0).toList

  /** The states after a bit field of `n` bits of the given order, from the states of `set`: `n` bits less are left. */
  private def bitStep(set: Int, le: Boolean, n: Int): Int =
    bitStates(set).foldLeft(0) { (acc, s) =>
      val left = (((s & 7) - n) % 8 + 8) % 8
      acc | (1 << (if (left == 0) 0 else if (le) 8 + left else left))
    }

  /** Some state of `set` has bits left by a read of the other order than `le`. */
  private def bitConflict(set: Int, le: Boolean): Boolean = (set & (if (le) BitsOfBe else BitsOfLe)) != 0

  /**
    * The states after the fields of `c`, which is entered in the states of `entry`, and the instances of `c` (each
    * of which is read from a stream of its own, at a byte boundary). `exitOf` gives the states after a type that a field
    * reads from the stream, from the states before it; `entered` is told each use of a type with the states before it;
    * `bad` is told each bit field that is read where the other bit order may have left bits.
    */
  private def bitWalk(
    c: ClassSpec,
    entry: Int,
    exitOf: (ClassSpec, Int) => Int,
    entered: (ClassSpec, Int) => Unit,
    bad: (AttrLikeSpec, Boolean) => Unit
  ): Int = {
    def bits(a: AttrLikeSpec, x: Int, le: Boolean, n: Int): Int = {
      if (bitConflict(x, le)) bad(a, le)
      bitStep(x, le, n)
    }
    def once(a: AttrLikeSpec, dt: DataType, x: Int): Int = dt match {
      case BitsType1(be) => bits(a, x, be != BigBitEndian, 1)
      case BitsType(w, be) => bits(a, x, be != BigBitEndian, w)
      case EnumType(_, _, b) => once(a, b, x)
      case ut: UserTypeInstream =>
        ut.classSpec match {
          case Some(u) if u.meta.isOpaque => 1
          case Some(u) => entered(u, x); exitOf(u, x)
          case None => x
        }
      case ut: UserTypeFromBytes =>
        ut.classSpec.foreach(u => entered(u, 1))
        1
      case st: SwitchType =>
        st.cases.values.foldLeft(if (st.hasElseCase) 0 else x)((acc, d) => acc | once(a, d, x))
      case _ => 1
    }
    def field(a: AttrLikeSpec, x: Int): Int = {
      val body = (y: Int) => once(a, a.dataType, y)
      val rep = a.cond.repeat match {
        case NoRepeat => body(x)
        case RepeatExpr(Ast.expr.IntNum(n)) if n <= 64 => (0 until n.toInt).foldLeft(x)((y, _) => body(y))
        case r =>
          // the states before each round, until there is none new; a count that is not known may also be 0
          var pre = x
          var seen = 0
          var out = if (r.isInstanceOf[RepeatUntil]) 0 else x
          while ((pre & ~seen) != 0) {
            seen |= pre
            pre = body(pre)
            out |= pre
          }
          out
      }
      if (a.cond.ifExpr.isDefined) x | rep else rep
    }
    c.instances.values.foreach {
      case p: ParseInstanceSpec => field(p, 1)
      case _ =>
    }
    c.seq.foldLeft(entry)((x, a) => field(a, x))
  }

  /**
    * A bit field of one bit order must not be read where the stream may hold bits that a bit field of the other order
    * left: the runtimes of the other targets keep the value of the bits that are left and take the next bits from them,
    * but the order of the bits within a byte is that of the read that took the first of them, and Kaitai Struct does
    * not define what the bits are then. The bit order may change only at a byte boundary. The states of the stream are
    * followed through the fields (`bitWalk`), with the number of bits left counted modulo 8, so that `b6` and `b10` of
    * the same order make two whole bytes. Where a field is not certainly read, or a type is read in several states, the
    * states are joined. A type is entered at a byte boundary where it is the top-level type of a description (through
    * its public `Parse`), or is not used, or is read through a substream, or by an instance, and in the states of every
    * other use. A type of foreign code (an opaque type) is taken to read whole bytes: the description does not say what
    * its parser does, and a hand-written one has to keep the contract of `Kaitai.Streams`.
    */
  private def checkBitOrder(): Unit = {
    val index = new java.util.IdentityHashMap[ClassSpec, Int]
    bitWorld.zipWithIndex.foreach { case (c, i) => index.put(c, i) }
    val exits = mutable.Map[(Int, Int), Int]()
    def exitOf(u: ClassSpec, x: Int): Int =
      bitStates(x).foldLeft(0)((acc, s) => acc | exits.getOrElse((index.get(u), s), 0))
    val nothing = (_: ClassSpec, _: Int) => ()
    val ignore = (_: AttrLikeSpec, _: Boolean) => ()
    var changed = true
    while (changed) {
      changed = false
      for (c <- bitWorld; s <- bitStates(BitsAny)) {
        val out = bitWalk(c, 1 << s, exitOf, nothing, ignore)
        if (out != exits.getOrElse((index.get(c), s), 0)) { exits((index.get(c), s)) = out; changed = true }
      }
    }
    val reached = mutable.Set[(Int, Int)]()
    val todo = mutable.Queue[(ClassSpec, Int)]()
    def enter(u: ClassSpec, x: Int): Unit =
      bitStates(x).foreach(s => if (reached.add((index.get(u), s))) todo.enqueue((u, s)))
    bitWorld.foreach(c => enter(c, 1))
    var first: Option[(Int, AttrLikeSpec, Boolean)] = None
    while (todo.nonEmpty) {
      val (c, s) = todo.dequeue()
      bitWalk(c, 1 << s, exitOf, enter, { (a, le) =>
        val i = bitWorld.indexWhere(_ eq c)
        if (first.forall(f => i < f._1)) first = Some((i, a, le))
      })
    }
    first.foreach { case (_, a, le) =>
      val (mine, other) = if (le) ("little", "big") else ("big", "little")
      fail(a.path, s"bit field `${idRaw(a.id)}` of $mine-endian bit order where bits of a $other-endian read may be left " +
        "(the bit order can change only at a byte boundary)")
    }
  }

  /** Only a type that contains itself is supported, no group of types that contain each other. */
  private def checkRecursion(): Unit =
    allClasses.foreach { c =>
      userTypesOf(c).filterNot(_ eq c).foreach { u =>
        if (reaches(u, c))
          fail(c.path, s"types ${c.nameAsStr} and ${u.nameAsStr} contain each other (only a type that contains itself is supported)")
      }
    }

  /** The class `target` seen from the level of the children of `parent`: the child that contains it. */
  private def childContaining(parent: ClassSpec, target: ClassSpec): Option[ClassSpec] = {
    var c: Option[ClassSpec] = Some(target)
    while (c.isDefined && !c.get.upClass.exists(_ eq parent)) c = c.get.upClass
    c
  }

  private def dependencies(child: ClassSpec): List[ClassSpec] = {
    val buf = ListBuffer[ClassSpec]()
    child.forEachRec(c => buf ++= userTypesOf(c))
    buf.toList
  }

  /** The nested types of a class, each after those it uses. */
  private def orderedChildren(cs: ClassSpec): List[ClassSpec] = {
    val children = cs.types.values.toList
    val done = ListBuffer[ClassSpec]()
    val visiting = mutable.Set[String]()
    def visit(c: ClassSpec): Unit = {
      if (done.exists(_ eq c)) return
      if (!visiting.add(c.nameAsStr)) fail(c.path, s"recursive type ${c.nameAsStr}")
      dependencies(c).flatMap(d => childContaining(cs, d)).filterNot(_ eq c).foreach(visit)
      done += c
    }
    children.foreach(visit)
    done.toList
  }

  private val belongsMemo = mutable.Map[String, Boolean]()

  def hasBelongs(cs: ClassSpec): Boolean = belongsMemo.getOrElseUpdate(cs.nameAsStr, {
    def dtHas(dt: DataType): Boolean = dt match {
      case _: BytesType | _: StrType => true
      case ut: UserTypeFromBytes if ut.process.isDefined => true
      case ut: UserType => (ut.classSpec.get eq cs) || hasBelongs(ut.classSpec.get)
      case st: SwitchType => st.cases.values.exists(dtHas)
      case _ => false
    }
    cs.seq.exists(a => !isContents(a) && (a.cond.repeat != NoRepeat && dtHasRepeat(a) || dtHas(a.dataType) && a.cond.repeat == NoRepeat)) ||
      hasIo(cs) || keptOf(cs).exists(k => dtHas(k.dataType))
  })

  private def dtHasRepeat(a: AttrLikeSpec): Boolean = true

  private def hasIo(cs: ClassSpec): Boolean =
    cs.instances.values.exists {
      case p: ParseInstanceSpec => p.io.isEmpty && !isKept(cs, p)
      case _ => false
    }

  private def containsParent(e: Ast.expr): Boolean = e match {
    case Ast.expr.Name(Ast.identifier(Identifier.PARENT)) => true
    case Ast.expr.Attribute(v, _) => containsParent(v)
    case Ast.expr.BinOp(l, _, r) => containsParent(l) || containsParent(r)
    case Ast.expr.Compare(l, _, r) => containsParent(l) || containsParent(r)
    case Ast.expr.BoolOp(_, vs) => vs.exists(containsParent)
    case Ast.expr.UnaryOp(_, v) => containsParent(v)
    case Ast.expr.IfExp(a, b, c) => containsParent(a) || containsParent(b) || containsParent(c)
    case Ast.expr.Call(f, args) => containsParent(f) || args.exists(containsParent)
    case Ast.expr.Subscript(a, b) => containsParent(a) || containsParent(b)
    case Ast.expr.List(es) => es.exists(containsParent)
    case Ast.expr.CastToType(v, _) => containsParent(v)
    case _ => false
  }

  private def rewriteParent(e: Ast.expr): Ast.expr = e match {
    case Ast.expr.Attribute(Ast.expr.Name(Ast.identifier(Identifier.PARENT)), a) => Ast.expr.Name(a)
    case Ast.expr.Attribute(v, a) => Ast.expr.Attribute(rewriteParent(v), a)
    case Ast.expr.BinOp(l, o, r) => Ast.expr.BinOp(rewriteParent(l), o, rewriteParent(r))
    case Ast.expr.Compare(l, o, r) => Ast.expr.Compare(rewriteParent(l), o, rewriteParent(r))
    case Ast.expr.BoolOp(o, vs) => Ast.expr.BoolOp(o, vs.map(rewriteParent))
    case Ast.expr.UnaryOp(o, v) => Ast.expr.UnaryOp(o, rewriteParent(v))
    case Ast.expr.IfExp(a, b, c) => Ast.expr.IfExp(rewriteParent(a), rewriteParent(b), rewriteParent(c))
    case Ast.expr.Call(f, args) => Ast.expr.Call(rewriteParent(f), args.map(rewriteParent))
    case Ast.expr.Subscript(a, b) => Ast.expr.Subscript(rewriteParent(a), rewriteParent(b))
    case Ast.expr.List(es) => Ast.expr.List(es.map(rewriteParent))
    case other => other
  }

  /** The type has a parameter `Order` that its caller computes */
  private def hasOrderParam(cs: ClassSpec): Boolean = cs.meta.endian match {
    case Some(CalcEndian(on, _)) => containsParent(on)
    case Some(InheritedEndian) => true
    case _ => false
  }

  private def storesOrder(cs: ClassSpec): Boolean = cs.meta.endian match {
    case Some(_: CalcEndian) | Some(InheritedEndian) => true
    case _ => false
  }

  // ------------------------------------------------------- outside references

  private def unsupported(msg: String): Nothing = throw new AdaUnsupported(msg)

  /**
    * A value that the parser of a type gets from outside as a parameter: an expression of the type that depends only
    * on the parameters of the description that are not integers, booleans or enumerations, and on `_parent` and `_root`
    * (`_parent.x`, `_root.x.y`, `hdr.width`, `_parent.s1 == "foo"`). The caller computes it. `raw` is the name of the
    * parameter of `Parse` and of the component of `T`: `_parent.x` is `Parent_X`, `_root.x.y` is `Root_X_Y`.
    */
  case class Ref(expr: Ast.expr, raw: String) {
    def source: String = showExpr(expr)
    def adaName: String = base(raw)
  }

  private val refTypes = mutable.Map[(String, Ref), DataType]()

  private def classFile(cs: ClassSpec): String = cs.name.head

  /** The class that `_root` means in `cs`: the top-level type of the description of `cs`. */
  private def rootOf(cs: ClassSpec): ClassSpec = classSpecs.get(classFile(cs)).getOrElse(topClass)

  private lazy val usersMemo: Map[String, List[ClassSpec]] = {
    val m = mutable.LinkedHashMap[String, ListBuffer[ClassSpec]]()
    allClasses.foreach { c =>
      useSites(c).map(_.classSpec.get).foreach { u =>
        if (classFile(u) == classFile(c)) {
          val l = m.getOrElseUpdate(u.nameAsStr, ListBuffer())
          if (!l.exists(_ eq c)) l += c
        }
      }
    }
    m.map(kv => kv._1 -> kv._2.toList).toMap
  }

  /** The uses of a type as a field or a parse instance of `cs`, with the arguments. */
  private def useSites(cs: ClassSpec): List[UserType] = {
    def of(dt: DataType): List[UserType] = dt match {
      case ut: UserType if ut.classSpec.isDefined => List(ut)
      case st: SwitchType => st.cases.values.toList.flatMap(of)
      case _ => Nil
    }
    cs.seq.flatMap(a => of(a.dataType)) ++ cs.instances.values.toList.flatMap {
      case p: ParseInstanceSpec => of(p.dataType)
      case _ => Nil
    }
  }

  /** The types of the same description that have a field of the type. */
  private def usersOf(cs: ClassSpec): List[ClassSpec] = usersMemo.getOrElse(cs.nameAsStr, Nil)

  private def ancestors(cs: ClassSpec, hops: Int): List[ClassSpec] = {
    var cur = List(cs)
    for (_ <- 1 to hops) {
      val next = ListBuffer[ClassSpec]()
      cur.flatMap(usersOf).foreach(c => if (!next.exists(_ eq c)) next += c)
      cur = next.toList
    }
    cur
  }

  private def memberOpt(cs: ClassSpec, name: String): Option[MemberSpec] =
    try Some(provider.resolveMember(cs, name)) catch { case _: Throwable => None }

  private def chainOf(e: Ast.expr): Option[(String, List[String])] = e match {
    case Ast.expr.Name(Ast.identifier(n)) if n == Identifier.PARENT || n == Identifier.ROOT => Some((n, Nil))
    case Ast.expr.Attribute(v, Ast.identifier(a)) => chainOf(v).map(c => (c._1, c._2 :+ a))
    case _ => None
  }

  /** A name followed by members, whatever the name is. */
  private def isChain(e: Ast.expr): Boolean = e match {
    case _: Ast.expr.Name => true
    case Ast.expr.Attribute(v, _) => isChain(v)
    case Ast.expr.CastToType(v, _) => isChain(v)
    case _ => false
  }

  private def chainNames(e: Ast.expr): List[String] = e match {
    case Ast.expr.Name(Ast.identifier(n)) => List(n)
    case Ast.expr.Attribute(v, Ast.identifier(a)) => chainNames(v) :+ a
    case Ast.expr.CastToType(v, _) => chainNames(v)
    case _ => Nil
  }

  /** The expression as it is written in a description, for messages. */
  private def showExpr(e: Ast.expr): String = {
    import Ast.expr._
    def op(o: Ast.operator): String = o match {
      case Ast.operator.Add => "+"
      case Ast.operator.Sub => "-"
      case Ast.operator.Mult => "*"
      case Ast.operator.Div => "/"
      case Ast.operator.Mod => "%"
      case Ast.operator.LShift => "<<"
      case Ast.operator.RShift => ">>"
      case Ast.operator.BitOr => "|"
      case Ast.operator.BitXor => "^"
      case Ast.operator.BitAnd => "&"
    }
    def cmp(o: Ast.cmpop): String = o match {
      case Ast.cmpop.Eq => "=="
      case Ast.cmpop.NotEq => "!="
      case Ast.cmpop.Lt => "<"
      case Ast.cmpop.LtE => "<="
      case Ast.cmpop.Gt => ">"
      case Ast.cmpop.GtE => ">="
    }
    e match {
      case Name(Ast.identifier(n)) => n
      case Attribute(v, Ast.identifier(a)) => showExpr(v) + "." + a
      case IntNum(n) => n.toString
      case Bool(b) => b.toString
      case Str(s) => "\"" + s + "\""
      case BinOp(l, o, r) => s"(${showExpr(l)} ${op(o)} ${showExpr(r)})"
      case Compare(l, o, r) => s"${showExpr(l)} ${cmp(o)} ${showExpr(r)}"
      case BoolOp(o, vs) => vs.map(showExpr).mkString(if (o == Ast.boolop.And) " and " else " or ")
      case UnaryOp(o, v) => (if (o == Ast.unaryop.Not) "not " else if (o == Ast.unaryop.Minus) "-" else "~") + showExpr(v)
      case IfExp(c, a, b) => s"${showExpr(c)} ? ${showExpr(a)} : ${showExpr(b)}"
      case CastToType(v, ty) => s"${showExpr(v)}.as<${ty.names.mkString("::")}>"
      case Subscript(a, i) => s"${showExpr(a)}[${showExpr(i)}]"
      case Call(f, args) => s"${showExpr(f)}(${args.map(showExpr).mkString(", ")})"
      case List(es) => es.map(showExpr).mkString("[", ", ", "]")
      case EnumByLabel(en, l, _) => s"${en.name}::${l.name}"
      case _ => "..."
    }
  }

  private def isPrimDt(dt: DataType): Boolean = dt match {
    case _: IntType | _: EnumType | _: BooleanType => true
    case _ => false
  }

  /** What an expression of outside values stands for, before it is a value of a known type. */
  private sealed trait OV
  private case class OVal(dt: DataType) extends OV
  private case class OParent(hops: Int) extends OV
  private case object ORoot extends OV
  private case object OIo extends OV

  private def memberValue(c: ClassSpec, a: String): Option[OV] = memberOpt(c, a).flatMap {
    case p: ParamDefSpec => Some(OVal(p.dataType))
    case at: AttrSpec =>
      if (at.cond.repeat != NoRepeat) Some(OVal(ArrayTypeInStream(at.dataType))) else Some(OVal(at.dataType))
    case v: ValueInstanceSpec => Some(OVal(v.dataType))
    case _ => None
  }

  private def isIntLike(o: OV): Boolean = o match {
    case OVal(_: IntType | _: EnumType) => true
    case _ => false
  }

  private def isBoolLike(o: OV): Boolean = o match {
    case OVal(_: BooleanType) => true
    case _ => false
  }

  /**
    * The type of an expression of `cs` that depends only on outside values (and literals), and whether it depends on
    * at least one. `None` for an expression that uses a value of the type itself, or that this does not understand.
    */
  private def outTypeOf(cs: ClassSpec, e: Ast.expr): Option[(OV, Boolean)] = {
    import Ast.expr._
    def both(l: Ast.expr, r: Ast.expr)(f: (OV, OV) => Option[OV]): Option[(OV, Boolean)] =
      outTypeOf(cs, l).flatMap { case (a, x) =>
        outTypeOf(cs, r).flatMap { case (b, y) => f(a, b).map(v => (v, x || y)) }
      }
    e match {
      case IntNum(_) | EnumByLabel(_, _, _) => Some((OVal(CalcIntType), false))
      case Bool(_) => Some((OVal(CalcBooleanType), false))
      case Str(_) => Some((OVal(CalcStrType), false))
      case Name(Ast.identifier(n)) =>
        if (n == Identifier.PARENT) Some((OParent(1), true))
        else if (n == Identifier.ROOT) { if (rootOf(cs) eq cs) None else Some((ORoot, true)) }
        else cs.params.find(p => idRaw(p.id) == n) match {
          case Some(p) if !isPrimDt(p.dataType) => Some((OVal(p.dataType), true))
          case _ => None
        }
      case Attribute(v, Ast.identifier(a)) =>
        outTypeOf(cs, v).flatMap { case (ov, _) =>
          val m: Option[OV] = ov match {
            case OParent(h) =>
              if (a == Identifier.PARENT) Some(OParent(h + 1))
              else if (a == Identifier.IO) Some(OIo)
              else ancestors(cs, h).view.flatMap(c => memberValue(c, a)).headOption
            case ORoot => if (a == Identifier.IO) None else memberValue(rootOf(cs), a)
            case OVal(ut: UserType) =>
              if (a.startsWith("_")) { if (a == Identifier.IO) Some(OIo) else None }
              else ut.classSpec.flatMap(c => memberValue(c, a))
            case OVal(_: StrType | _: BytesType) =>
              if (a == "length" || a == "size") Some(OVal(CalcIntType)) else None
            case OVal(_: ArrayType) => if (a == "size") Some(OVal(CalcIntType)) else None
            case OIo => if (a == "size") Some(OVal(CalcIntType)) else None
            case OVal(KaitaiStreamType | OwnedKaitaiStreamType) => if (a == "size") Some(OVal(CalcIntType)) else None
            case _ => None
          }
          m.map(x => (x, true))
        }
      case CastToType(v, ty) =>
        // an outside value that is cast to a type is that value; the caller reads it as its own, whose type it knows
        outTypeOf(cs, v).flatMap {
          case (ov @ (OParent(_) | ORoot | OVal(_: StructType)), true) if !ty.isArray =>
            val c = try Some(provider.resolveClassSpec(ty)) catch { case _: Throwable => None }
            c.map { cl =>
              val u = UserTypeInstream(cl.name, None)
              u.classSpec = Some(cl)
              (OVal(u), true)
            }
          case _ => None
        }
      case Subscript(a, i) =>
        both(a, i) {
          case (OVal(at: ArrayType), ix) if isIntLike(ix) => Some(OVal(at.elType))
          case (OVal(_: BytesType), ix) if isIntLike(ix) => Some(OVal(CalcIntType))
          case _ => None
        }
      case BinOp(l, _, r) => both(l, r) { (a, b) => if (isIntLike(a) && isIntLike(b)) Some(OVal(CalcIntType)) else None }
      case Compare(l, _, r) => both(l, r)((_, _) => Some(OVal(CalcBooleanType)))
      case BoolOp(_, vs) =>
        val ts = vs.map(outTypeOf(cs, _))
        if (ts.forall(t => t.exists(x => isBoolLike(x._1)))) Some((OVal(CalcBooleanType), ts.exists(_.get._2))) else None
      case UnaryOp(o, v) =>
        outTypeOf(cs, v).flatMap { case (t, x) =>
          if (o == Ast.unaryop.Not) { if (isBoolLike(t)) Some((OVal(CalcBooleanType), x)) else None }
          else if (isIntLike(t)) Some((OVal(CalcIntType), x)) else None
        }
      case IfExp(c, a, b) =>
        for {
          cx <- outTypeOf(cs, c) if isBoolLike(cx._1)
          ax <- outTypeOf(cs, a)
          bx <- outTypeOf(cs, b)
          r <- if (isBoolLike(ax._1) && isBoolLike(bx._1)) Some(OVal(CalcBooleanType))
               else if (isIntLike(ax._1) && isIntLike(bx._1)) Some(OVal(CalcIntType)) else None
        } yield (r, cx._2 || ax._2 || bx._2)
      case _ => None
    }
  }

  /** The type of a value that is passed as it is; an integer that an expression computes is an S64. */
  private def refType(dt: DataType): DataType = dt match {
    case CalcIntType => IntMultiType(signed = true, Width8, Some(LittleEndian))
    case other => other
  }

  /** An expression that has a value of a type that is not passed on its own (a string, a user type, ...) in it. */
  private def hasWholeValue(cs: ClassSpec, e: Ast.expr): Boolean = {
    import Ast.expr._
    if (isChain(e)) outTypeOf(cs, e) match {
      case Some((OVal(dt), true)) => !isPrimDt(dt)
      case Some((_, true)) => true
      case _ => false
    }
    else e match {
      case Attribute(v, _) => hasWholeValue(cs, v)
      case BinOp(l, _, r) => hasWholeValue(cs, l) || hasWholeValue(cs, r)
      case Compare(l, _, r) => hasWholeValue(cs, l) || hasWholeValue(cs, r)
      case BoolOp(_, vs) => vs.exists(hasWholeValue(cs, _))
      case UnaryOp(_, v) => hasWholeValue(cs, v)
      case IfExp(a, b, c) => hasWholeValue(cs, a) || hasWholeValue(cs, b) || hasWholeValue(cs, c)
      case Call(f, args) => hasWholeValue(cs, f) || args.exists(hasWholeValue(cs, _))
      case Subscript(a, b) => hasWholeValue(cs, a) || hasWholeValue(cs, b)
      case _ => false
    }
  }

  private def procExprs(p: Option[ProcessExpr]): List[Ast.expr] = p match {
    case Some(ProcessXor(k)) => List(k)
    case Some(ProcessRotate(_, k)) => List(k)
    case Some(ProcessCustom(_, args)) => args.toList
    case _ => Nil
  }

  /** The arguments of a use of a type that are passed: those for parameters that are integers, booleans or enumerations. */
  private def passedArgs(ut: UserType): List[Ast.expr] = ut.classSpec match {
    case Some(c) if c.params.size == ut.args.size =>
      ut.args.zip(c.params).collect { case (a, p) if isPrimDt(p.dataType) => a }.toList
    case _ => ut.args.toList
  }

  private def dtExprs(dt: DataType): List[Ast.expr] = dt match {
    case BytesLimitType(size, _, _, _, proc) => size :: procExprs(proc)
    case BytesEosType(_, _, _, proc) => procExprs(proc)
    case BytesTerminatedType(_, _, _, _, proc) => procExprs(proc)
    case StrFromBytesType(bt, _, _) => dtExprs(bt)
    case ut: UserTypeFromBytes => passedArgs(ut) ++ dtExprs(ut.bytes) ++ procExprs(ut.process)
    case ut: UserType => passedArgs(ut)
    case st: SwitchType => st.on :: st.cases.toList.flatMap { case (k, v) => k :: dtExprs(v) }
    case _ => Nil
  }

  private def validExprs(v: Option[ValidationSpec]): List[Ast.expr] = v match {
    case Some(ValidationEq(e)) => List(e)
    case Some(ValidationMin(e)) => List(e)
    case Some(ValidationMax(e)) => List(e)
    case Some(ValidationRange(lo, hi)) => List(lo, hi)
    case Some(ValidationAnyOf(vs)) => vs.toList
    case Some(ValidationExpr(e)) => List(e)
    case _ => Nil
  }

  private def attrExprs(a: AttrLikeSpec): List[Ast.expr] =
    a.cond.ifExpr.toList ++ (a.cond.repeat match {
      case RepeatExpr(e) => List(e)
      case RepeatUntil(e) => List(e)
      case _ => Nil
    }) ++ dtExprs(a.dataType) ++ (a match {
      case at: AttrSpec => validExprs(at.valid)
      case p: ParseInstanceSpec => validExprs(p.valid) ++ p.pos.toList ++ p.io.toList
      case _ => Nil
    })

  /** Every expression written in the type, except the calculation of a byte order that mentions `_parent` */
  private def outsideExprs(cs: ClassSpec): List[Ast.expr] =
    cs.seq.flatMap(attrExprs) ++ cs.instances.values.toList.flatMap {
      case v: ValueInstanceSpec => v.value :: v.ifExpr.toList
      case p: ParseInstanceSpec => attrExprs(p)
    } ++ (cs.meta.endian match {
      case Some(ce: CalcEndian) if !containsParent(ce.on) => ce.on :: ce.cases.keys.toList
      case _ => Nil
    })

  /**
    * The values from outside that the type needs for `expr`: the largest subexpressions that depend only on outside
    * values and are integers, booleans or enumerations, where such a subexpression has a string, a user type or the
    * like in it; otherwise the integer, boolean or enumeration that a chain `_parent.x`, `hdr.width` ends in.
    */
  private def scanRefs(cs: ClassSpec, expr: Ast.expr): List[(Ast.expr, DataType)] = {
    val out = ListBuffer[(Ast.expr, DataType)]()
    def isRootIoChain(e: Ast.expr): Boolean = chainOf(e) match {
      case Some((Identifier.ROOT, Identifier.IO :: _)) => true
      case _ => false
    }
    def children(e: Ast.expr): Unit = e match {
      case Ast.expr.Attribute(v, _) => walk(v)
      case Ast.expr.BinOp(l, _, r) => walk(l); walk(r)
      case Ast.expr.Compare(l, _, r) => walk(l); walk(r)
      case Ast.expr.BoolOp(_, vs) => vs.foreach(walk)
      case Ast.expr.UnaryOp(_, v) => walk(v)
      case Ast.expr.IfExp(a, b, c) => walk(a); walk(b); walk(c)
      case Ast.expr.Call(f, args) => walk(f); args.foreach(walk)
      case Ast.expr.Subscript(a, b) => walk(a); walk(b)
      case Ast.expr.List(es) => es.foreach(walk)
      case Ast.expr.CastToType(v, _) => walk(v)
      case Ast.expr.EnumById(_, v, _) => walk(v)
      case _ =>
    }
    def checkRoot(c: List[String]): Unit =
      if (c.head == Identifier.ROOT && !c.tail.headOption.contains(Identifier.IO) && c.tail.nonEmpty && isRecursive(rootOf(cs)))
        // The value that a nested top-level value would need is the one of the outermost value, not its own.
        unsupported("`_root` in a description whose top-level type contains itself")
    def walk(e: Ast.expr): Unit = {
      if (isChain(e)) checkRoot(chainNames(e))
      val typed = if (isRootIoChain(e)) None else outTypeOf(cs, e)
      typed match {
        case Some((OVal(dt), true)) if isPrimDt(dt) =>
          if (isChain(e) || hasWholeValue(cs, e)) { chainLeaves(e).foreach(checkRoot); out += ((e, refType(dt))) } else children(e)
        case Some((OParent(_), true)) => unsupported(s"`${showExpr(e)}` used as a value")
        case Some((ORoot, true)) => unsupported(s"`${showExpr(e)}` used as a value")
        case Some((OIo, true)) => unsupported(s"`${showExpr(e)}`: only `.size` of a stream from outside is supported")
        case Some((OVal(dt), true)) if isChain(e) =>
          unsupported(s"`${showExpr(e)}` has the type ${describeType(dt)}; only integers, booleans and enumerations can be passed")
        case None if isChain(e) && !isRootIoChain(e) && (chainNames(e).head == Identifier.PARENT || (chainNames(e).head == Identifier.ROOT && !(rootOf(cs) eq cs))) =>
          val hops = chainNames(e).takeWhile(_ == Identifier.PARENT).size
          if (chainNames(e).head == Identifier.PARENT && ancestors(cs, hops).isEmpty)
            unsupported(s"`${List.fill(hops)("_parent").mkString(".")}` in type ${cs.nameAsStr}, which no type of the description has as a field")
          else unsupported(s"`${showExpr(e)}`: no such member in the type that has the field, or not a value that can be passed")
        case _ => children(e)
      }
    }
    walk(expr)
    out.toList
  }

  private def describeType(dt: DataType): String = dt match {
    case _: StrType => "string"
    case _: BytesType => "bytes"
    case _: UserType => "a user type"
    case _: ArrayType => "array"
    case other => other.toString
  }

  private def refParamType(dt: DataType, source: String): String = dt match {
    case _: IntType | _: EnumType | _: BooleanType => intAda(dt)
    case other => unsupported(s"`$source` has the type ${describeType(other)}; only integers, booleans and enumerations can be passed")
  }

  /** The name of the parameter of `Parse` for an expression: `_parent.x` is `parent_x`; another expression is named after its first chain. */
  private def rawName(expr: Ast.expr, taken: Seq[Ref]): String = {
    def path(e: Ast.expr): Option[String] = e match {
      case Ast.expr.Name(Ast.identifier(n)) => Some(n.stripPrefix("_"))
      case Ast.expr.Attribute(v, Ast.identifier(a)) => path(v).map(_ + "_" + a.stripPrefix("_"))
      case Ast.expr.Subscript(v, Ast.expr.IntNum(i)) => path(v).map(_ + "_" + i)
      case Ast.expr.CastToType(v, _) => path(v)
      case _ => None
    }
    val raw =
      if (path(expr).isDefined) path(expr).get
      else chainLeaves(expr).headOption.map(_.map(_.stripPrefix("_")).mkString("_") + "_expr").getOrElse("outside_expr")
    if (!taken.exists(_.raw == raw)) raw
    else Iterator.from(2).map(i => s"${raw}_$i").find(n => !taken.exists(_.raw == n)).get
  }

  /** The chains in an expression, in the order of reading. */
  private def chainLeaves(e: Ast.expr): List[List[String]] = {
    import Ast.expr._
    if (isChain(e)) chainNames(e) :: Nil
    else e match {
      case Attribute(v, _) => chainLeaves(v)
      case BinOp(l, _, r) => chainLeaves(l) ++ chainLeaves(r)
      case Compare(l, _, r) => chainLeaves(l) ++ chainLeaves(r)
      case BoolOp(_, vs) => vs.toList.flatMap(chainLeaves)
      case UnaryOp(_, v) => chainLeaves(v)
      case IfExp(a, b, c) => chainLeaves(a) ++ chainLeaves(b) ++ chainLeaves(c)
      case Call(f, args) => chainLeaves(f) ++ args.flatMap(chainLeaves)
      case Subscript(a, b) => chainLeaves(a) ++ chainLeaves(b)
      case _ => Nil
    }
  }

  /** The node of an expression, rebuilt with `f` applied to each child */
  private def mapChildren(e: Ast.expr)(f: Ast.expr => Ast.expr): Ast.expr = {
    import Ast.expr._
    e match {
      case Attribute(v, a) => Attribute(f(v), a)
      case BinOp(l, o, r) => BinOp(f(l), o, f(r))
      case Compare(l, o, r) => Compare(f(l), o, f(r))
      case BoolOp(o, vs) => BoolOp(o, vs.map(f))
      case UnaryOp(o, v) => UnaryOp(o, f(v))
      case IfExp(a, b, c) => IfExp(f(a), f(b), f(c))
      case Call(g, args) => Call(f(g), args.map(f))
      case Subscript(a, b) => Subscript(f(a), f(b))
      case List(es) => List(es.map(f))
      case CastToType(v, t) => CastToType(f(v), t)
      case EnumById(n, v, t) => EnumById(n, f(v), t)
      case other => other
    }
  }

  private def parentHops(e: Ast.expr): Option[Int] = e match {
    case Ast.expr.Name(Ast.identifier(Identifier.PARENT)) => Some(1)
    case Ast.expr.Attribute(v, Ast.identifier(Identifier.PARENT)) => parentHops(v).map(_ + 1)
    case _ => None
  }

  private def parentChain(hops: Int): Ast.expr =
    (2 to hops).foldLeft[Ast.expr](Ast.expr.Name(Ast.identifier(Identifier.PARENT)))((v, _) =>
      Ast.expr.Attribute(v, Ast.identifier(Identifier.PARENT)))

  /**
    * The expression `e` of the type `callee`, which `caller` uses with the arguments of `ut`, as it reads in `caller`:
    * what is `_parent.x` for the callee is `x`, a parameter is the argument that the caller gives for it.
    */
  private def liftExpr(caller: ClassSpec, ut: UserType, callee: ClassSpec, e0: Ast.expr): Ast.expr = {
    // a cast of an outside value only tells its type; the caller reads the value as its own
    def strip(e: Ast.expr): Ast.expr = e match {
      case Ast.expr.CastToType(v, _) if isChain(v) => strip(v)
      case _ => mapChildren(e)(strip)
    }
    def go(e: Ast.expr): Ast.expr = e match {
      case Ast.expr.Attribute(v, Ast.identifier(a)) if parentHops(e).isEmpty && parentHops(v).isDefined =>
        val h = parentHops(v).get
        if (ut.forcedParent.isDefined) {
          val base: Ast.expr = ut.forcedParent.get match {
            case Ast.expr.Bool(false) =>
              unsupported(s"the key `parent: false` on a field of type ${callee.nameAsStr}, which uses `_parent`")
            case p => p
          }
          Ast.expr.Attribute((2 to h).foldLeft(base)((x, _) => Ast.expr.Attribute(x, Ast.identifier(Identifier.PARENT))), Ast.identifier(a))
        } else if (h == 1) Ast.expr.Name(Ast.identifier(a))
        else Ast.expr.Attribute(parentChain(h - 1), Ast.identifier(a))
      case _ if parentHops(e).isDefined =>
        val h = parentHops(e).get
        if (ut.forcedParent.isDefined) unsupported("`_parent` used as a value")
        else if (h == 1) unsupported("`_parent` used as a value") else parentChain(h - 1)
      case Ast.expr.Attribute(v, Ast.identifier(a))
          if (rootOf(caller) eq caller) && a != Identifier.IO && chainOf(v).exists(c => c._1 == Identifier.ROOT && c._2.isEmpty) =>
        Ast.expr.Name(Ast.identifier(a))
      case Ast.expr.Name(Ast.identifier(n)) if callee.params.exists(p => idRaw(p.id) == n && !isPrimDt(p.dataType)) =>
        ut.args(callee.params.indexWhere(p => idRaw(p.id) == n))
      case _ =>
        mapChildren(e)(go) match {
          // an element of a list that the caller gives as an argument
          case Ast.expr.Subscript(Ast.expr.List(es), Ast.expr.IntNum(i)) if i >= 0 && i < es.size => es(i.toInt)
          case other => other
        }
    }
    go(strip(e0))
  }

  private def containsRoot(e: Ast.expr): Boolean = e match {
    case Ast.expr.Name(Ast.identifier(Identifier.ROOT)) => true
    case _ =>
      var found = false
      mapChildren(e) { c => if (containsRoot(c)) found = true; c }
      found
  }

  private lazy val refsMemo: Map[String, List[Ref]] = {
    val refs = mutable.LinkedHashMap[String, ListBuffer[Ref]]()
    allClasses.foreach(c => refs(c.nameAsStr) = ListBuffer())
    def add(c: ClassSpec, e: Ast.expr, dt: DataType): Boolean =
      if (refs(c.nameAsStr).exists(_.expr == e)) false
      else {
        guard(c.path)(refParamType(dt, showExpr(e)))
        if (refs(c.nameAsStr).size >= 64) fail(c.path, "more than 64 values from outside are needed by one type")
        val r = Ref(e, rawName(e, refs(c.nameAsStr).toList))
        refs(c.nameAsStr) += r
        refTypes((c.nameAsStr, r)) = dt
        true
      }
    allClasses.foreach { c =>
      guard(c.path) {
        outsideExprs(c).foreach(e => scanRefs(c, e).foreach { case (x, dt) => add(c, x, dt) })
      }
    }
    var changed = true
    while (changed) {
      changed = false
      allClasses.foreach { c =>
        useSites(c).foreach { ut =>
          val b = ut.classSpec.get
          if (ut.args.size == b.params.size) refs(b.nameAsStr).toList.foreach { rb =>
            if (!(containsRoot(rb.expr) && (rootOf(c) ne rootOf(b)))) guard(c.path) {
              val up = liftExpr(c, ut, b, rb.expr)
              scanRefs(c, up).foreach { case (x, dt) => changed |= add(c, x, dt) }
            }
          }
        }
      }
    }
    allClasses.foreach { c =>
      refs(c.nameAsStr).find(r => containsParent(r.expr)).foreach { r =>
        if (rootOf(c) eq c) fail(c.path, s"`${r.source}` in the top-level type of a description, which has no parent")
      }
    }
    refs.map(kv => kv._1 -> kv._2.toList).toMap
  }

  private def refsOf(cs: ClassSpec): List[Ref] = refsMemo.getOrElse(cs.nameAsStr, Nil)

  /** The parameters of the type that are passed to `Parse` and kept in `T`: those that are integers, booleans or enumerations. */
  private def keptParams(cs: ClassSpec): List[ParamDefSpec] = cs.params.filter(p => isPrimDt(p.dataType))

  override def outsideRef(cs: ClassSpec, e: Ast.expr): Option[Either[(String, DataType), Ast.expr]] = e match {
    case _: Ast.expr.IntNum | _: Ast.expr.Str | _: Ast.expr.Bool => None
    case _ =>
      chainOf(e) match {
        case Some((Identifier.ROOT, attrs)) if attrs.nonEmpty && attrs.head != Identifier.IO && (rootOf(cs) eq cs) =>
          Some(Right(attrs.tail.foldLeft[Ast.expr](Ast.expr.Name(Ast.identifier(attrs.head)))((v, a) => Ast.expr.Attribute(v, Ast.identifier(a)))))
        case _ =>
          refsOf(cs).find(_.expr == e).map(r => Left((r.adaName, refTypes((cs.nameAsStr, r)))))
      }
  }

  /** Names of the seq fields of `cs` that the value of `e` depends on, instances taken apart. */
  private def memberDeps(cs: ClassSpec, e: Ast.expr, seen: Set[String] = Set()): Set[String] = e match {
    case Ast.expr.Name(Ast.identifier(n)) if !n.startsWith("_") =>
      memberOpt(cs, n) match {
        case Some(v: ValueInstanceSpec) if !seen.contains(n) =>
          (v.value :: v.ifExpr.toList).flatMap(x => memberDeps(cs, x, seen + n)).toSet
        case Some(_: AttrSpec) => Set(n)
        case _ => Set()
      }
    case Ast.expr.Attribute(v, _) => memberDeps(cs, v, seen)
    case Ast.expr.BinOp(l, _, r) => memberDeps(cs, l, seen) ++ memberDeps(cs, r, seen)
    case Ast.expr.Compare(l, _, r) => memberDeps(cs, l, seen) ++ memberDeps(cs, r, seen)
    case Ast.expr.BoolOp(_, vs) => vs.flatMap(memberDeps(cs, _, seen)).toSet
    case Ast.expr.UnaryOp(_, v) => memberDeps(cs, v, seen)
    case Ast.expr.IfExp(a, b, c) => memberDeps(cs, a, seen) ++ memberDeps(cs, b, seen) ++ memberDeps(cs, c, seen)
    case Ast.expr.Call(f, args) => memberDeps(cs, f, seen) ++ args.flatMap(memberDeps(cs, _, seen))
    case Ast.expr.Subscript(a, b) => memberDeps(cs, a, seen) ++ memberDeps(cs, b, seen)
    case Ast.expr.List(es) => es.flatMap(memberDeps(cs, _, seen)).toSet
    case _ => Set()
  }

  // ------------------------------------------- parse instances that the seq needs

  private def exprKids(e: Ast.expr): List[Ast.expr] = e match {
    case Ast.expr.Attribute(v, _) => List(v)
    case Ast.expr.BinOp(l, _, r) => List(l, r)
    case Ast.expr.Compare(l, _, r) => List(l, r)
    case Ast.expr.BoolOp(_, vs) => vs.toList
    case Ast.expr.UnaryOp(_, v) => List(v)
    case Ast.expr.IfExp(a, b, c) => List(a, b, c)
    case Ast.expr.Call(f, args) => f :: args.toList
    case Ast.expr.Subscript(a, b) => List(a, b)
    case Ast.expr.List(es) => es.toList
    case Ast.expr.CastToType(v, _) => List(v)
    case Ast.expr.EnumById(_, v, _) => List(v)
    case _ => Nil
  }

  /**
    * The expressions name the field `a` of `cs`: directly, as `_root.a` in the top type, or through the value
    * instances and the parse instances that they name.
    */
  private def namesField(cs: ClassSpec, es: List[Ast.expr], a: AttrSpec): Boolean = {
    val seen = mutable.Set[String]()
    def named(n: String): Boolean =
      memberOpt(cs, n) match {
        case Some(m: AttrSpec) => m.id == a.id
        case Some(v: ValueInstanceSpec) if !seen.contains(n) =>
          seen += n
          (v.value :: v.ifExpr.toList).exists(walk)
        case Some(p: ParseInstanceSpec) if !seen.contains(n) =>
          seen += n
          attrExprs(p).exists(walk)
        case _ => false
      }
    def walk(e: Ast.expr): Boolean = e match {
      case Ast.expr.Name(Ast.identifier(n)) if !n.startsWith("_") => named(n)
      case Ast.expr.Attribute(Ast.expr.Name(Ast.identifier(Identifier.ROOT)), Ast.identifier(n)) if cs.upClass.isEmpty => named(n)
      case _ => exprKids(e).exists(walk)
    }
    es.exists(walk)
  }

  /** `_io.pos` or `_io.eof` is written in the expression */
  private def mentionsIoPos(e: Ast.expr): Boolean = e match {
    case Ast.expr.Attribute(Ast.expr.Name(Ast.identifier(Identifier.IO)), Ast.identifier("pos" | "eof")) => true
    case _ => exprKids(e).exists(mentionsIoPos)
  }

  /**
    * The parse instances of `cs` that the expressions need: those they name, and those that the value instances and
    * the parse instances they name need in turn, each after those it needs.
    */
  private def instanceUses(cs: ClassSpec, es: List[Ast.expr]): List[ParseInstanceSpec] = {
    val out = ListBuffer[ParseInstanceSpec]()
    val seenValues = mutable.Set[String]()
    def walk(e: Ast.expr, path: List[String]): Unit = e match {
      case Ast.expr.Name(Ast.identifier(n)) if !n.startsWith("_") =>
        memberOpt(cs, n) match {
          case Some(v: ValueInstanceSpec) if !seenValues.contains(n) =>
            seenValues += n
            (v.value :: v.ifExpr.toList).foreach(walk(_, path))
          case Some(p: ParseInstanceSpec) =>
            if (path.contains(n)) throw new AdaUnsupported(s"parse instances that need each other (`$n`)")
            if (!out.exists(_.id == p.id)) {
              attrExprs(p).foreach(walk(_, n :: path))
              if (!out.exists(_.id == p.id)) out += p
            }
          case _ =>
        }
      case _ => exprKids(e).foreach(walk(_, path))
    }
    es.foreach(walk(_, Nil))
    out.toList
  }

  /** Why `Parse` cannot keep the parse instance; empty if it can. */
  private def keptShape(p: ParseInstanceSpec): String = {
    val reason: Option[String] =
      if (p.cond.repeat != NoRepeat) Some("it has `repeat`")
      else if (AdaTranslator.hasProcess(p.dataType)) Some("it has `process`")
      else if (p.pos.isEmpty) Some("it has no `pos`")
      else if (p.cond.ifExpr.isDefined) Some("it has `if`")
      else p.dataType match {
        case _: SwitchType => Some("its type depends on a value")
        case _: FloatType => Some("it is a float")
        case _ =>
          p.io match {
            case None => None
            case Some(e) if isRootIoExpr(e) =>
              if (attrExprs(p).exists(mentionsIoPos)) Some("it has `io: _root._io` and `_io.pos` or `_io.eof` in an expression") else None
            case Some(_) => Some("it has an `io` other than `_root._io`")
          }
      }
    reason.getOrElse("")
  }

  private val keptMemo = mutable.Map[String, List[ParseInstanceSpec]]()

  /** The parse instances of `cs` that an expression of its `seq` needs, and that `Parse` therefore keeps. */
  private def keptOf(cs: ClassSpec): List[ParseInstanceSpec] = keptMemo.getOrElseUpdate(cs.nameAsStr, {
    val all = guard(cs.path)(instanceUses(cs, cs.seq.toList.flatMap(attrExprs)))
    all.filter(p => keptShape(p).isEmpty)
  })

  private def isKept(cs: ClassSpec, p: ParseInstanceSpec): Boolean = keptOf(cs).exists(_.id == p.id)

  override def instanceNotKept(cs: ClassSpec, inst: ParseInstanceSpec): Option[String] =
    if (isKept(cs, inst)) None
    else {
      val shape = keptShape(inst)
      Some(if (shape.isEmpty) "only an instance that an expression of the `seq` needs can be used, and none does" else s"it cannot be kept: $shape")
    }

  /** The instance depends on `_io.pos` or `_io.eof`, itself or through the instances it needs */
  private def dependsOnIoPos(cs: ClassSpec, p: ParseInstanceSpec): Boolean =
    (p :: instanceUses(cs, attrExprs(p))).exists(q => attrExprs(q).exists(mentionsIoPos))

  /**
    * The expressions of a field by when they are evaluated: `ifE` always, at the start of the field; `start` once
    * when the field is there, before it is read; `until` after the first element of `repeat-until`; `valid` after the
    * field is read; `late` once per element of a repetition, or only in some case of a switch.
    */
  private case class Slots(ifE: List[Ast.expr], start: List[Ast.expr], until: List[Ast.expr], valid: List[Ast.expr], late: List[Ast.expr])

  private def slotsOf(a: AttrSpec): Slots = {
    val ifE = a.cond.ifExpr.toList
    val (own, perElement) = a.dataType match {
      case st: SwitchType => (List(st.on), st.cases.toList.flatMap { case (k, v) => k :: dtExprs(v) })
      case dt => (dtExprs(dt), Nil)
    }
    val valid = validExprs(a.valid)
    a.cond.repeat match {
      case NoRepeat => Slots(ifE, own, Nil, valid, perElement)
      case RepeatExpr(e) => Slots(ifE, List(e), Nil, Nil, own ++ perElement ++ valid)
      case RepeatEos => Slots(ifE, Nil, Nil, Nil, own ++ perElement ++ valid)
      case RepeatUntil(c) => Slots(ifE, own, List(c), Nil, perElement ++ valid)
    }
  }

  /** What `Parse` does to read the parse instances that the field needs, decided before the field is generated */
  private case class Plan(pre: List[String] = Nil, loop: List[String] = Nil, invariant: List[String] = Nil)

  private var plan: Plan = Plan()

  /** How often the generator of the field took `plan.pre`, and whether it took `plan.loop` */
  private var preTaken = 0
  private var loopTaken = false

  private def planLoop: List[String] = {
    loopTaken = true
    plan.loop
  }

  /** Terms for the loop invariant of the loop that reads parse instances */
  private def planInvariant: String = plan.invariant.map(" and then " + _).mkString

  /** Kept instances that `Parse` has read on every way to the field being generated, and those it reads inside a loop */
  private val certain = mutable.Set[String]()
  private val flagged = mutable.Set[String]()

  /**
    * The statements that read the parse instance into `This`, at the position of `S`: from a copy of `S`, which is
    * joined to `S` afterwards, so that `S` stays where it is and fails if the instance cannot be read.
    */
  private def keptRead(cs: ClassSpec, p: ParseInstanceSpec, rc: RC, flag: Boolean): List[String] = {
    val nm = plain(idRaw(p.id))
    val bs = base(idRaw(p.id))
    val l = rc.scope.fresh("L")
    rc.scope.decls += s"$l : ${KS}Stream;"
    if (flag) rc.scope.needsInit = true
    val rcl = rc.copy(s = l, path = p.path)
    val init = if (p.io.isDefined) s"$l := ${KS}Open (Buffer);" else s"$l := S;"
    val posT = T(p.pos.get, rcl, "Pos")
    val seek = guarded(posT.guards, List(s"${KS}Seek ($l, ${sizeCode(posT)});"), rcl, init = false)
    val target = s"This.$nm"
    val reads = readValue(p.dataType, target, rcl) ++ p.valid.toList.flatMap(v => validate(v, p.dataType, target, rcl))
    val body = List(init) ++ seek ++ reads ++ List(s"${KS}Join (S, $l);")
    if (flag) List(s"if not This.${hasNm(bs)} then") ++ ind(body ++ List(s"This.${hasNm(bs)} := ${KS}OK (S);")) ++ List("end if;")
    else body
  }

  /**
    * Decides where `Parse` reads the parse instances that the field `a` (number `i` of the `seq`) needs, and puts it in
    * `plan`. An instance is read where an expression first needs it, once, and every instance that `Parse` keeps has
    * to be read on every way through `Parse`, because its accessor is a function. So an instance may be first needed
    * only where the field is certainly evaluated.
    */
  private def planAttr(cs: ClassSpec, a: AttrSpec, i: Int, rc: RC): Unit = {
    plan = Plan()
    val sl = slotsOf(a)
    val kq = q(idRaw(a.id))
    def need(es: List[Ast.expr]) = instanceUses(cs, es).filter(p => isKept(cs, p))
    def withDeps(ps: List[ParseInstanceSpec]) =
      ps.flatMap(p => need(attrExprs(p)) :+ p).distinct
    val ifU = need(sl.ifE)
    val startU = need(sl.start)
    val untilU = need(sl.until)
    val validU = need(sl.valid)
    val lateU = need(sl.late)
    if (ifU.isEmpty && startU.isEmpty && untilU.isEmpty && validU.isEmpty && lateU.isEmpty) return
    val pre = ListBuffer[String]()
    val loop = ListBuffer[String]()
    val inv = ListBuffer[String]()
    def key(p: ParseInstanceSpec) = idRaw(p.id)
    def fieldsBefore(p: ParseInstanceSpec): Unit =
      (p :: instanceUses(cs, attrExprs(p))).flatMap(attrExprs).flatMap(e => memberDeps(cs, e)).foreach { n =>
        if (cs.seq.indexWhere(x => idRaw(x.id) == n) >= i)
          throw new AdaUnsupported(s"parse instance `${key(p)}` is first needed by the field `${idRaw(a.id)}`, but it needs the field `$n`, which is read at the same place or after")
      }
    def top(ps: List[ParseInstanceSpec]): Unit = ps.filterNot(p => certain.contains(key(p))).foreach { p =>
      fieldsBefore(p)
      pre ++= keptRead(cs, p, rc, flag = false)
      certain += key(p)
    }
    def conditional(ps: List[ParseInstanceSpec], why: String): Unit = ps.filterNot(p => certain.contains(key(p))).foreach { p =>
      throw new AdaUnsupported(s"parse instance `${key(p)}` is first needed $why, where it may not be evaluated at all; it can be kept only if it is certainly read")
    }
    top(ifU)
    if (a.cond.ifExpr.isEmpty) {
      top(startU)
      // before the loop, where the position of the stream does not matter
      top(withDeps(untilU.filterNot(p => dependsOnIoPos(cs, p))))
      top(validU.filterNot(p => dependsOnIoPos(cs, p)))
      validU.filter(p => dependsOnIoPos(cs, p) && !certain.contains(key(p))).foreach { p =>
        throw new AdaUnsupported(s"parse instance `${key(p)}` is first needed by the `valid` of the field $kq and depends on `_io.pos` or `_io.eof`, which would be taken after the field is read")
      }
      val inLoop = withDeps(untilU.filter(p => dependsOnIoPos(cs, p))).filterNot(p => certain.contains(key(p)))
      inLoop.foreach { p =>
        fieldsBefore(p)
        flagged += key(p)
        loop ++= keptRead(cs, p, rc, flag = true)
        p.dataType match {
          case ut: UserType => inv += s"(if This.${hasNm(base(key(p)))} then ${userPkg(ut)}.Valid (This.${plain(key(p))}))"
          case _ =>
        }
      }
      inLoop.foreach(p => certain += key(p))
    } else {
      conditional(startU, s"by the field $kq, which has an `if`")
      conditional(untilU, s"by the field $kq, which has an `if`")
      conditional(validU, s"by the field $kq, which has an `if`")
    }
    conditional(lateU, s"by an expression of the field $kq that is evaluated for each element of a repetition, or only in some case of a `switch-on`")
    plan = Plan(pre.toList, loop.toList, inv.toList)
  }

  /** The accessor and the component of a parse instance that `Parse` keeps */
  private def genKeptInstance(cs: ClassSpec, p: ParseInstanceSpec, o: Out): Unit = {
    val nm = plain(idRaw(p.id))
    val bs = base(idRaw(p.id))
    val k = idRaw(p.id)
    val dt = p.dataType
    val (stored, default) = storedType(dt, p.path)
    o.comps += s"$nm : $stored${default.map(d => s" := $d").getOrElse("")};"
    if (flagged.contains(k)) o.comps += s"${hasNm(bs)} : Boolean := False;"
    val after = List("Parse read it once, where an expression of the `seq` first needed it, and keeps it in This") ++
      (if (p.io.isDefined) List("It is read from the whole of Buffer (`io: _root._io`)") else Nil)
    val pre = "Valid (This)"
    dt match {
      case et: EnumType =>
        enumAccessors(o, nm, bs, stored, et, pre, s"Instance ${q(k)}", "as the integer that is in the data", "The integer in the data", p.doc, after)
      case ut: UserType =>
        val pkg = userPkg(ut)
        accessor(o, nm, stored, pre, Some(s"$pkg.Valid ($nm'Result)"), s"This.$nm",
          comment = describe(List(s"Instance ${q(k)}, ${whatIs(dt)}"), p.doc, after))
        o.valid += s"$pkg.Valid (This.$nm)"
        if (hasBelongs(ut.classSpec.get)) o.belongs += s"$pkg.Belongs_To (This.$nm, Buffer)"
      case _: BytesType | _: StrType =>
        accessor(o, nm, stored, pre, None, s"This.$nm", comment = describe(sliceHead(s"Instance ${q(k)}", dt), p.doc, after))
        o.belongs += s"${KT}Within (This.$nm, Buffer)"
      case _ =>
        accessor(o, nm, stored, pre, None, s"This.$nm", comment = describe(List(s"Instance ${q(k)}, ${whatIs(dt)}"), p.doc, after))
    }
    o.kept += nm
  }

  /** Position in the seq of the field that is being generated; larger than any for an instance. */
  private var curSeqIdx: Int = Int.MaxValue

  // ------------------------------------------------------------ output helpers

  private def ind(lines: Seq[String], n: Int = 1): List[String] =
    lines.toList.map(l => if (l.isEmpty) l else ("   " * n) + l)

  // ------------------------------------------------------------ documentation

  /**
    * Nesting depth of the package that is generated: 0 for the library-level one. The declarations of its visible
    * part are indented by three blanks more than the package itself, which decides how long a line of a comment may
    * be: gnatformat does the indenting afterwards, and the style checks of the generated code ask for 120 columns.
    */
  private var level = 0

  private def columns(indent: Int): Int = 120 - indent - 4

  private def memberColumns: Int = columns(3 * (level + 1))

  /** Control characters and line separators, which would end a comment or confuse a reader, become blanks. */
  private def sanitize(s: String): String =
    s.map { c =>
      val t = Character.getType(c)
      if (Character.isISOControl(c) || t == Character.LINE_SEPARATOR || t == Character.PARAGRAPH_SEPARATOR ||
          (c >= '\u202a' && c <= '\u202e') || (c >= '\u2066' && c <= '\u2069')) ' ' else c
    }

  /**
    * The width of a text in the source. A character beyond ASCII counts as twice its bytes in UTF-8: gnatformat reads a
    * source as Latin-1 and writes every byte of it as a character of UTF-8, so the line must be short enough then too.
    */
  private def bytesOf(s: String): Int =
    s.codePoints.toArray.map(cp => if (cp < 128) 1 else 2 * new String(Character.toChars(cp)).getBytes("UTF-8").length).sum

  /** A word that is longer than a line is cut into pieces that fit. */
  private def pieces(w: String, width: Int): List[String] =
    if (bytesOf(w) <= width) List(w)
    else {
      var i = 0
      var n = 0
      def step: Int = Character.charCount(w.codePointAt(i))
      while (i < w.length && n + bytesOf(w.substring(i, i + step)) <= width) {
        n += bytesOf(w.substring(i, i + step))
        i += step
      }
      if (i == 0) List(w) else w.substring(0, i) :: pieces(w.substring(i), width)
    }

  /** The lines of a text, each at most `width` bytes long. */
  private def wrapText(text: String, width: Int): List[String] = {
    val words = sanitize(text).split("\\s+").toList.filter(_.nonEmpty)
    // A word that starts with `@` stays with the word before it, so that no line starts with a tag of GNATdoc
    val tokens = ListBuffer[String]()
    words.foreach { w =>
      if (w.startsWith("@") && tokens.nonEmpty) tokens(tokens.size - 1) = tokens.last + " " + w else tokens += w
    }
    val lines = ListBuffer[String]()
    var cur = ""
    tokens.toList.flatMap { t =>
      if (!t.contains(' ')) pieces(t, width)
      else if (bytesOf(t) <= width) List(t)
      else t.split(" ").toList.flatMap(pieces(_, width))
    }.foreach { w =>
      if (cur.isEmpty) cur = w
      else if (bytesOf(cur) + 1 + bytesOf(w) > width) { lines += cur; cur = w }
      else cur = cur + " " + w
    }
    if (cur.nonEmpty) lines += cur
    lines.toList
  }

  /** A paragraph of a comment, or the blank line between two */
  private type Item = Option[String]
  private def P(text: String): Item = Some(text)
  private val Gap: Item = None

  private def render(items: List[Item], indent: Int = -1): List[String] = {
    val width = columns(if (indent < 0) 3 * (level + 1) else indent)
    items.flatMap {
      case Some(t) => wrapText(t, width).map(l => s"--  $l")
      case None => List("--")
    }
  }

  /** A comment of one paragraph */
  private def wrapComment(text: String): List[String] = render(List(P(text)))

  private def q(name: String): String = "`" + name + "`"

  private def endSentence(s: String): String = {
    val t = s.trim
    if (t.isEmpty || t.endsWith(".") || t.endsWith("!") || t.endsWith("?") || t.endsWith(":")) t else t + "."
  }

  /** One phrase has no full stop, several sentences have one each. */
  private def sentences(parts: List[String]): String = parts.filter(_.trim.nonEmpty) match {
    case List(one) => one.trim
    case many => many.map(endSentence).mkString(" ")
  }

  /** The text of a `doc` in paragraphs, as it is written: a blank line ends a paragraph, a list item begins one. */
  private def docItems(doc: DocSpec): List[Item] = {
    val out = ListBuffer[Item]()
    val cur = new StringBuilder
    def flush(): Unit = if (cur.nonEmpty) { out += Some(cur.toString); cur.clear() }
    val listItem = "^([-*+]|[0-9]+[.)])\\s.*".r
    doc.summary.toList.flatMap(_.split("\r\n|\r|\n", -1)).foreach { raw =>
      val line = sanitize(raw).trim
      if (line.isEmpty) { flush(); if (out.nonEmpty && out.last.isDefined) out += Gap }
      else if (listItem.pattern.matcher(line).matches) { flush(); cur ++= line }
      else { if (cur.nonEmpty) cur += ' '; cur ++= line }
    }
    flush()
    while (out.nonEmpty && out.last.isEmpty) out.remove(out.size - 1)
    out.toList
  }

  private def refText(r: RefSpec): String = r match {
    case TextRef(t) => t
    case UrlRef(u, t) => if (t == "Source") u else s"$u $t"
  }

  private def refItems(doc: DocSpec): List[Item] = doc.ref.map(r => P("See " + refText(r)))

  /**
    * The comment of a declaration: `head` as phrases or sentences, then the first paragraph of the description,
    * then `after`; the other paragraphs of the description, and its references, follow.
    */
  private def describe(head: List[String], doc: DocSpec, after: List[String] = Nil): List[String] = {
    val items = docItems(doc)
    val refs = refItems(doc)
    val (first, rest) = items match {
      case Some(p) :: tl => (List(p), tl)
      case _ => (Nil, Nil)
    }
    val parts = head ++ first ++ after
    val main: List[Item] =
      if (rest.isEmpty) {
        val t = sentences(parts)
        List(P(if (refs.nonEmpty && parts.size == 1) endSentence(t) else t))
      } else List(P(sentences(head ++ first))) ++ rest ++ (if (after.isEmpty) Nil else List(Gap, P(sentences(after))))
    render(main ++ refs)
  }

  /** The description of an enumeration value, a parameter, ... as one line of text, for a tag of GNATdoc */
  private def oneLine(doc: DocSpec): List[String] = (docItems(doc).flatten ++ refItems(doc).flatten).toList

  /** `@param Name text` and the like; the text goes on in the lines that follow */
  private def tag(kind: String, name: String, text: String): List[String] =
    render(List(P(s"@$kind $name $text")))

  private def docLines(doc: DocSpec): List[String] = describe(Nil, doc)

  private class Scope {
    val decls = ListBuffer[String]()
    private val counts = mutable.Map[String, Int]()
    var needsInit = false
    var passesThis = false
    var bit = false
    def fresh(b: String): String = {
      val n = counts.getOrElse(b, 0) + 1
      counts(b) = n
      if (n == 1) b else s"${b}_$n"
    }
  }

  /** Context of the statements of a read */
  private case class RC(s: String, order: String, scope: Scope, path: List[String], w: Boolean = false)

  private class Out {
    val pub = ListBuffer[String]()
    val privTypes = ListBuffer[String]()
    val comps = ListBuffer[String]()
    val privFuncs = ListBuffer[String]()
    val valid = ListBuffer[String]()
    val belongs = ListBuffer[String]()
    val parse = ListBuffer[String]()
    val bodyConsts = ListBuffer[String]()
    val bodyBefore = ListBuffer[String]()
    /** The subprograms that evaluate expressions with floats for `Parse` and `Write`, and the names they were given */
    val steps = ListBuffer[String]()
    val stepNames = mutable.Map[String, String]()
    val stepCounts = mutable.Map[String, Int]()
    val bodyAfter = ListBuffer[String]()
    val write = ListBuffer[String]()
    val wscope = new Scope
    /** Fields that `Parse` goes over once but does not keep, and parse instances and processed fields that it does not look at */
    val rereads = ListBuffer[String]()
    val unread = ListBuffer[String]()
    /** Parse instances that `Parse` reads once and keeps */
    val kept = ListBuffer[String]()
  }

  /** The translation of an expression of a statement; one with a float is evaluated by a subprogram of its own */
  private def T(e: Ast.expr, rc: RC, role: String = "", unique: Boolean = false): ATr = floatStep(e, Tplain(e, rc), rc, role, unique)

  /** The translation of an expression, as it is written where it is used */
  private def Tplain(e: Ast.expr, rc: RC): ATr = {
    tr.buffer = Some("Buffer")
    tr.io = Some(rc.s)
    tr.thisName = "This"
    tr.iterator = None
    tr.knownValid = Set()
    guard(rc.path)(tr.translate(e))
  }

  // ------------------------------------------------ float expressions in procedures

  /** The `Out` of the class that is being generated; None outside of it */
  private var stepOut: Out = null

  /** Names that the generated procedures declare and that a subprogram of the package cannot see */
  private val StepLocals: Set[String] = ParamReserved ++ Set("buffer", "s", "w", "l", "target", "number", "before", "order", "depth")

  /** How a subprogram that evaluates an expression gets what the expression uses */
  private case class StepCtx(params: List[(String, String)], args: List[String], sub: String => String, pre: List[String] = Nil)

  private def exprMentionsIterator(e: Ast.expr): Boolean = e match {
    case Ast.expr.Name(Ast.identifier(Identifier.ITERATOR)) => true
    case _ => exprKids(e).exists(exprMentionsIterator)
  }

  private def exprHasFloat(e: Ast.expr): Boolean = tr.isFloatNode(e) || exprKids(e).exists(exprHasFloat)

  /** The names in `text` that are not part of a longer name and not numbers */
  private def leadingNames(text: String): Set[String] =
    "(?<![\\w.'#])[A-Za-z_][A-Za-z0-9_]*".r.findAllIn(text.replaceAll("(?<![A-Za-z0-9_])\\d[0-9A-Za-z_#.]*", " ")).toSet

  /**
    * What a subprogram that evaluates the expression `e`, whose translation is in `text`, takes as parameters: the
    * record `This`, and where the expression uses `_` or `_index` of a loop, the value (`Item`) and the number
    * (`Index`). None if it uses anything else of the procedure (the buffer, the stream, a variable), or has no float.
    */
  private def stepCtx(e: Ast.expr, text: String, rc: RC, usesBuffer: Boolean): Option[StepCtx] = {
    val itFloat = tr.iterator.exists(_._1.isInstanceOf[FloatMultiType]) && exprMentionsIterator(e)
    if (stepOut == null || usesBuffer || !(exprHasFloat(e) || itFloat)) return None
    val it = tr.iterator.filter(_._2.matches("[A-Za-z_]\\w*"))
    val ix = tr.indexCode
    def sub(x: String): String = {
      var r = x
      it.foreach { case (_, code) => r = r.replaceAll("(?<![\\w.'])" + java.util.regex.Pattern.quote(code) + "\\b", "Item") }
      // as a whole expression only: `This.I - 1` of a field `i` is not the index `I - 1` of the loop
      ix.foreach(c => if (c != "Index") r = r.replaceAll("(?<![\\w.'])" + java.util.regex.Pattern.quote(c) + "(?![\\w.])", "Index"))
      r
    }
    val sx = sub(text)
    val names = leadingNames(sx)
    val own = Set("this", "item", "index")
    val locals = StepLocals ++ Set(rc.s.toLowerCase) ++ rc.scope.decls.toList.map(_.takeWhile(c => c != ' ' && c != ':').toLowerCase)
    if (names.exists(n => !own(n.toLowerCase) && locals(n.toLowerCase))) return None
    val params = ListBuffer[(String, String)]()
    val args = ListBuffer[String]()
    if (names.contains("This")) { params += (("This", "T")); args += "This" }
    if (names.contains("Item")) {
      val ty = try storedType(it.get._1, rc.path)._1 catch { case _: Throwable => return None }
      params += (("Item", ty)); args += it.get._2
    }
    if (names.contains("Index")) { params += (("Index", KT + "Length")); args += ix.get }
    // the element of a repetition of a type is valid where the loop uses it, and the accessors of the type need it
    val pre =
      if (names.contains("Item") && tr.knownValid.contains(it.get._2) && it.get._1.isInstanceOf[UserType]) {
        val ty = params.find(_._1 == "Item").get._2
        List((if (ty == "T") "" else ty.stripSuffix("T")) + "Valid (Item)")
      } else Nil
    if (params.isEmpty) None else Some(StepCtx(params.toList, args.toList, sub, pre))
  }

  /**
    * Declares the subprogram that evaluates a float expression for a procedure, once for equal ones, and returns the
    * expression that stands for its value. `value` is the expression, `defined` the condition under which it is
    * defined, if there is one, and `dflt` the value where it is not. The prover sees only the declaration of the
    * subprogram, which says nothing, so the float operations stay out of the context of the procedure.
    *
    * Without a condition the subprogram is a function `Eval_X`. With one it is a procedure that computes both at once,
    * `Eval_X (This, Eval_Defined, Eval_Holds)` (or `Eval_Value` for an integer): the guard that the translation
    * returns is the variable `Eval_Defined`, its code is the other variable, and the call is marked in the guard to be
    * written before the statement that uses them (see `expandStepCalls`). Two functions, one for the condition and one
    * for the value, would evaluate the condition twice.
    */
  private def makeStep(role: String, rc: RC, ret: String, vt: VT, defined: Option[String], value: String, dflt: String, ctx: StepCtx, unique: Boolean = false): ATr = {
    val o = stepOut
    val params = ctx.params.map { case (n, t) => s"$n : $t" }.mkString("; ")
    val contract = "Global => null" + (if (ctx.pre.isEmpty) "" else ctx.pre.mkString(", Pre => ", " and then ", ""))
    val key = List(ret, params, defined.getOrElse(""), value, dflt, contract).mkString("|")
    val name = o.stepNames.getOrElseUpdate(key, {
      val member = rc.path.takeRight(2) match {
        case List("seq", i) if i.nonEmpty && i.forall(_.isDigit) && i.toInt < provider.nowClass.seq.size => base(idRaw(provider.nowClass.seq(i.toInt).id))
        case List("instances", n) => base(n)
        case _ => "Step"
      }
      val b = "Eval_" + member + (if (role.isEmpty) "" else "_" + role)
      val n = o.stepCounts.getOrElse(b, 0) + 1
      o.stepCounts(b) = n
      val nm = if (n == 1) b else s"${b}_$n"
      val what = role match {
        case "If" => "the condition (`if`)"
        case "Size" => "the size"
        case "Count" => "the number of repetitions (`repeat-expr`)"
        case "Until" => "the end of the repetition (`repeat-until`)"
        case "Valid" => "the check of `valid`"
        case "Min" => "the check of the lower limit of `valid`"
        case "Max" => "the check of the upper limit of `valid`"
        case "Pos" => "the position (`pos`)"
        case "On" => "the expression of `switch-on`"
        case "Order" => "the byte order"
        case "Arg" => "an argument"
        case _ => "an expression"
      }
      o.steps += s"--  The result of $what of ${q(member)}, which computes with floats."
      o.steps += "--  It is a subprogram of its own so that the proof of Parse does not see the float operations."
      defined match {
        case None =>
          o.steps ++= List(s"function $nm ($params) return $ret with $contract;", "",
            s"function $nm ($params) return $ret is", "begin", s"   return $value;", s"end $nm;", "")
        case Some(d) =>
          val ps = s"$params; Eval_Defined : out Boolean; Eval_Result : out $ret"
          o.steps ++= List(s"procedure $nm ($ps) with $contract;", "",
            s"procedure $nm ($ps) is", "begin", s"   Eval_Defined := $d;", "   if Eval_Defined then", s"      Eval_Result := $value;",
            "   else", s"      Eval_Result := $dflt;", "   end if;", s"end $nm;", "")
      }
      nm
    })
    val args = ctx.args.mkString(", ")
    // the subprogram takes the whole record, which has to be set by then
    if (ctx.params.exists(_._1 == "This")) rc.scope.passesThis = true
    defined match {
      case None => ATr(s"$name ($args)", 0, Nil, vt)
      case Some(_) =>
        // The variables are shared by the steps of a procedure, which is what the prover takes best (twelve steps with a
        // variable each did not prove, with three shared did), unless the results of several steps are used together
        val dv = if (unique) name + "_Defined" else "Eval_Defined"
        val rv = if (unique) name + "_Result" else if (ret == "Boolean") "Eval_Holds" else "Eval_Value"
        List(s"$dv : Boolean;", s"$rv : $ret;").foreach(d => if (!rc.scope.decls.contains(d)) rc.scope.decls += d)
        ATr(rv, 0, List(s"$StepOpen$name ($args, $dv, $rv);$StepClose$dv"), vt)
    }
  }

  private val StepOpen = "\u0001"
  private val StepClose = "\u0002"

  /** Writes each call of a procedure that evaluates a float expression, which is marked in a condition, before the line */
  private def expandStepCalls(lines: List[String]): List[String] =
    lines.flatMap(_.split("\n", -1).toList).flatMap { l =>
      if (!l.contains(StepOpen)) List(l)
      else {
        val indent = l.takeWhile(_ == ' ')
        val calls = s"$StepOpen(.*?)$StepClose".r.findAllMatchIn(l).map(m => indent + m.group(1)).toList
        calls ++ List(s"$StepOpen.*?$StepClose".r.replaceAllIn(l, ""))
      }
    }

  private def floatStep(e: Ast.expr, t: ATr, rc: RC, role: String, unique: Boolean): ATr = {
    if (!(t.vt == VInt || t.vt == VBool) || t.isLiteral) return t
    stepCtx(e, (t.code :: t.guards).mkString("\n"), rc, t.usesBuffer) match {
      case None => t
      case Some(ctx) =>
        val gs = t.guards.map(ctx.sub)
        val (ret, dflt) = if (t.vt == VInt) (KT + "S64", "0") else ("Boolean", "False")
        makeStep(role, rc, ret, t.vt, if (gs.isEmpty) None else Some(conjoin(gs)), ctx.sub(t.code), dflt, ctx, unique)
    }
  }

  private def conjoin(gs: List[String]): String = gs.mkString(" and then ")

  private def failStmt(rc: RC, reason: String): String =
    if (rc.w) s"${KW}Fail (W, $KT$reason);" else s"${KS}Fail (${rc.s}, $KT$reason);"

  /** Statements that run only where all guards hold; otherwise the stream fails. */
  private def guarded(gs: List[String], thenStmts: List[String], rc: RC, elseStmts: List[String] = Nil, init: Boolean = true): List[String] =
    if (gs.isEmpty) thenStmts
    else {
      if (init) rc.scope.needsInit = true
      List(s"if ${conjoin(gs)} then") ++ ind(thenStmts) ++ List("else") ++
        ind(failStmt(rc, "Arithmetic_Error") :: elseStmts) ++ List("end if;")
    }

  private def sizeCode(t: ATr): String =
    if (t.isLiteral && t.lo >= 0 && t.hi < (BigInt(1) << 31)) t.code else s"${KT}To_Size (${t.code})"

  private def countCode(t: ATr): String =
    if (t.isLiteral && t.lo >= 0 && t.hi < (BigInt(1) << 31)) t.code
    else if (t.isLiteral) "0"
    else s"${KT}To_Count (${t.code})"

  // ----------------------------------------------------------------- types

  private def intAda(dt: DataType): String = dt match {
    case EnumType(_, _, b) => intAda(b)
    case _: BooleanType => "Boolean"
    case _ =>
      AdaTranslator.intInfo(dt).map(i => KT + i._1).getOrElse(throw new AdaUnsupported(s"type $dt"))
  }

  private def plainInt(dt: DataType): String = intAda(dt).stripPrefix(KT)

  /** The width of a bit field, or of the bit field that an enumeration is over, below 64 bits */
  private def narrowBits(dt: DataType): Option[Int] = dt match {
    case BitsType(w, _) if w < 64 => Some(w)
    case EnumType(_, _, BitsType(w, _)) if w < 64 => Some(w)
    case _ => None
  }

  /**
    * The type of an element of a repetition of bit fields. The value of a bit field is below 2**w, and a subtype of
    * its own tells the proof, wherever the element goes: into a kept component, an expression, `Next`.
    */
  private def bitsElementType(bs: String, dt: DataType): String =
    if (narrowBits(dt).isDefined) s"${bs}_Element" else intAda(dt)

  private def floatBits(w: IntWidth): String = if (w.width == 4) KT + "U32" else KT + "U64"

  private def defaultOf(adaType: String): String = if (adaType == "Boolean") "False" else "0"

  private def userPkg(ut: UserType): String = packageOf(ut.classSpec.get)

  /** Prefix for a name of the package of `cs`: none inside the package itself */
  private def qualOf(cs: ClassSpec): String = if (cs eq provider.nowClass) "" else packageOf(cs) + "."

  /** Ada type of the stored value of a non-repeated, non-switch type */
  private def storedType(dt: DataType, path: List[String]): (String, Option[String]) = dt match {
    case _: IntType | _: EnumType | _: BooleanType =>
      val t = guard(path)(intAda(dt))
      (t, Some(defaultOf(t)))
    case FloatMultiType(w, _) =>
      val t = floatBits(w)
      (t, Some("0"))
    case _: BytesType | _: StrType => (KT + "Slice", None)
    case ut: UserType => (userPkg(ut) + ".T", None)
    case other => fail(path, s"type $other")
  }

  // ------------------------------------------------------------- the reading

  private def orderOf(rc: RC, dt: DataType): String = {
    if (rc.order.isEmpty) throw new AdaUnsupported(s"byte order of $dt is not known")
    rc.order
  }

  private def readInt(dt: DataType, target: String, rc: RC): List[String] = dt match {
    case Int1Type(sg) =>
      List(s"${KS}Read_${if (sg) "S1" else "U1"} (Buffer, ${rc.s}, $target);")
    case IntMultiType(sg, w, e) =>
      val nm = s"Read_${if (sg) "S" else "U"}${w.width}"
      e match {
        case Some(fe) => List(s"$KS$nm${fe.toSuffix} (Buffer, ${rc.s}, $target);")
        case None => List(s"$KS$nm (Buffer, ${rc.s}, ${orderOf(rc, dt)}, $target);")
      }
    case FloatMultiType(w, e) =>
      val nm = s"Read_U${w.width}"
      e match {
        case Some(fe) => List(s"$KS$nm${fe.toSuffix} (Buffer, ${rc.s}, $target);")
        case None => List(s"$KS$nm (Buffer, ${rc.s}, ${orderOf(rc, dt)}, $target);")
      }
    case BitsType1(be) =>
      rc.scope.bit = true
      opTypes += "U64"
      List(s"${KS}Read_Bits_Int_${if (be == BigBitEndian) "Be" else "Le"} (Buffer, ${rc.s}, 1, Bit);", s"$target := Bit /= 0;")
    case BitsType(w, be) =>
      if (w > 64) throw new AdaUnsupported(s"bit field of $w bits")
      List(s"${KS}Read_Bits_Int_${if (be == BigBitEndian) "Be" else "Le"} (Buffer, ${rc.s}, $w, $target);")
    case EnumType(_, _, b) => readInt(b, target, rc)
    case other => throw new AdaUnsupported(s"type $other")
  }

  private def bytesLiteral(bs: Seq[Int]): String =
    if (bs.size == 1) f"(1 => 16#${bs.head}%02X#)" else bs.map(b => f"16#$b%02X#").mkString("(", ", ", ")")

  private def unsignedByte(b: Byte): Int = b & 0xff

  private def postBytes(
    target: String,
    term: Option[Seq[Byte]],
    include: Boolean,
    pad: Option[Int]
  ): List[String] = {
    // the padding is not stripped if it is the terminator: the terminator is applied to the whole
    val strip = pad.filter(p => term.forall(t => p != unsignedByte(t.last))).toList.map(p => s"$target := ${KB}Strip_Right (Buffer, $target, $p);")
    val terminate = term.toList.map { t =>
      if (t.size == 1)
        s"$target := ${KB}Terminate_At (Buffer, $target, ${unsignedByte(t.head)}, ${if (include) "True" else "False"});"
      else
        s"$target := ${KB}Terminate_At_Multi (Buffer, $target, ${bytesLiteral(t.map(unsignedByte))}, ${if (include) "True" else "False"});"
    }
    strip ++ terminate
  }

  private def readBytes(bt: BytesType, target: String, rc: RC, defaultTarget: Boolean): List[String] = {
    bt match {
      case BytesLimitType(size, term, include, pad, _) =>
        val t = T(size, rc, "Size")
        val read = s"${KS}Read_Bytes (${rc.s}, ${sizeCode(t)}, $target);" :: postBytes(target, term, include, pad)
        guarded(t.guards, read, rc, if (defaultTarget) List(s"$target := (First => 1, Last => 0);") else Nil)
      case BytesEosType(term, include, pad, _) =>
        s"${KS}Read_Bytes_Full (${rc.s}, $target);" :: postBytes(target, term, include, pad)
      case BytesTerminatedType(term, include, consume, eos, _) =>
        val args = s"Include => ${b(include)}, Consume => ${b(consume)}, EOS_Error => ${b(eos)}, Data => $target"
        if (term.size == 1)
          List(s"${KS}Read_Bytes_Term (Buffer, ${rc.s}, Term => ${unsignedByte(term.head)}, $args);")
        else
          List(s"${KS}Read_Bytes_Term_Multi (Buffer, ${rc.s}, Term => ${bytesLiteral(term.map(unsignedByte))}, $args);")
      case other => throw new AdaUnsupported(s"bytes $other")
    }
  }

  private def b(x: Boolean): String = if (x) "True" else "False"

  private def withPath(path: List[String])(f: => List[String]): List[String] = guard(path)(f)

  /** Statements that read a value of any type into `target`. */
  private def readValue(dt: DataType, target: String, rc: RC, defaultTarget: Boolean = false): List[String] =
    withPath(rc.path) {
      dt match {
        case _: IntType | _: EnumType | _: FloatType | _: BooleanType => readInt(dt, target, rc)
        case bt: BytesType => readBytes(bt, target, rc, defaultTarget)
        case StrFromBytesType(bt, _, _) if bt.process.isDefined => throw new AdaUnsupported("`process` on a string")
        case StrFromBytesType(bt, enc, _) =>
          val read = readBytes(bt, target, rc, defaultTarget)
          val e = encodingName(enc, rc.path)
          if (e == "Kaitai.Strings.Single_Byte") read
          else
            read ++ List(
              s"if not ${KStr}Is_Valid (Buffer, $target, $e) then",
              "   " + failStmt(rc, "Illegal_Sequence"),
              "end if;"
            )
        case ut: UserTypeInstream => userCall(ut, target, rc)
        case ut: UserTypeFromBytes => userCallSub(ut, target, rc)
        case other => throw new AdaUnsupported(s"type $other")
      }
    }

  // arguments of a call of the parser of another type

  private def paramAda(p: ParamDefSpec): String = p.dataType match {
    case _: IntType | _: EnumType | _: BooleanType => intAda(p.dataType)
    case other => throw new AdaUnsupported(s"parameter `${p.id.humanReadable}` of type $other")
  }

  private def convertArg(t: ATr, ada: String, p: ParamDefSpec): (String, List[String]) = {
    val plainT = ada.stripPrefix(KT)
    if (ada == "Boolean") {
      if (t.vt != VBool) throw new AdaUnsupported(s"argument for `${p.id.humanReadable}` is not a boolean")
      (t.code, Nil)
    } else {
      t.vt match {
        case VInt | VEnum(_) =>
        case _ => throw new AdaUnsupported(s"argument for `${p.id.humanReadable}` is not an integer")
      }
      val (_, plo, phi) = AdaTranslator.intInfo(p.dataType match {
        case EnumType(_, _, bb) => bb
        case o => o
      }).get
      if (t.native.exists(_._2 == plainT)) (t.native.get._1, Nil)
      else if (plainT == "S64") (t.code, Nil)
      else if (t.isLiteral && t.lo >= plo && t.hi <= phi) (t.code, Nil)
      else if (t.lo >= plo && t.hi <= phi) (s"$ada (${t.code})", Nil)
      else (s"$ada (${t.code})", List(s"${t.atom} in $plo .. $phi"))
    }
  }

  /** Byte order that a caller passes on to a type */
  private def orderArg(callee: ClassSpec, rc: RC): (List[String], Option[String]) = callee.meta.endian match {
    case Some(ce: CalcEndian) if containsParent(ce.on) =>
      val v = rc.scope.fresh("Order")
      rc.scope.decls += s"$v : ${KT}Byte_Order;"
      val ce2 = CalcEndian(rewriteParent(ce.on), ce.cases)
      (calcOrder(ce2, v, rc), Some(v))
    case Some(InheritedEndian) =>
      provider.nowClass.meta.endian match {
        case Some(LittleEndian) => (Nil, Some(KT + "Little_Endian"))
        case Some(BigEndian) => (Nil, Some(KT + "Big_Endian"))
        case Some(_) => (Nil, Some(rc.order))
        case None => (List(failStmt(rc, "Undecided_Endianness")), Some(KT + "Little_Endian"))
      }
    case _ => (Nil, None)
  }

  /** Statements that compute the byte order of a calculated endianness into `target`. */
  private def calcOrder(ce: CalcEndian, target: String, rc: RC): List[String] = {
    def lit(e: FixedEndian) = if (e == LittleEndian) KT + "Little_Endian" else KT + "Big_Endian"
    val elseCase = ce.cases.collectFirst { case (k, v) if k == SwitchType.ELSE_CONST => v }
    val labeled = ce.cases.toList.filter(_._1 != SwitchType.ELSE_CONST)
    val conds = labeled.map { case (k, v) => (T(Ast.expr.Compare(ce.on, Ast.cmpop.Eq, k), rc, "Order", unique = true), v) }
    val gs = conds.flatMap(_._1.guards).distinct
    val chain = ListBuffer[String]()
    conds.zipWithIndex.foreach { case ((c, v), i) =>
      chain += s"${if (i == 0) "if" else "elsif"} ${c.code} then"
      chain += s"   $target := ${lit(v)};"
    }
    val elseStmts = elseCase match {
      case Some(e) => List(s"$target := ${lit(e)};")
      case None => List(failStmt(rc, "Undecided_Endianness"), s"$target := ${KT}Little_Endian;")
    }
    val body =
      if (conds.isEmpty) elseStmts
      else chain.toList ++ List("else") ++ ind(elseStmts) ++ List("end if;")
    guarded(gs, body, rc, List(s"$target := ${KT}Little_Endian;"))
  }

  /** What kind of value an argument is, for a message */
  private def kindOf(vt: VT): String = vt match {
    case VInt | VU64Lit(_) => "an integer"
    case VFloat => "a float"
    case VBool => "a boolean"
    case VEnum(_) => "an enumeration"
    case VBytes | VBytesLit(_) => "bytes"
    case VStr(_) | VStrLit(_) => "a string"
    case VUser(_) => "a value of a type"
    case VArray => "an array"
    case VStream | VRootStream => "a stream"
  }

  /**
    * The arguments that a call of the parser of an opaque type gets: the arguments of the description and nothing else,
    * an integer as a `Kaitai.Types.S64` and a boolean as a `Boolean` (see "Foreign code" in docs/codegen.md).
    */
  private def opaqueArgs(ut: UserType, rc: RC): (List[String], List[String]) = {
    val pre = ListBuffer[String]()
    val args = ListBuffer[String]()
    ut.args.zipWithIndex.foreach { case (a, i) =>
      val t = T(a, rc, "Arg")
      val ada = t.vt match {
        case VInt => KT + "S64"
        case VBool => "Boolean"
        case other => unsupported(s"argument ${i + 1} of the opaque type `${ut.classSpec.get.nameAsStr}`, which is ${kindOf(other)}; only integers and booleans can be passed")
      }
      if (t.guards.isEmpty) args += t.code
      else {
        val v = rc.scope.fresh("Arg")
        rc.scope.decls += s"$v : $ada;"
        pre ++= guarded(t.guards, List(s"$v := ${t.code};"), rc, List(s"$v := ${defaultOf(ada)};"), init = false)
        args += v
      }
    }
    (pre.toList, args.toList)
  }

  /** Statements before the call, and the arguments of the call (including the byte order). */
  private def callArgs(ut: UserType, rc: RC): (List[String], List[String]) = {
    val callee = ut.classSpec.get
    if (callee.meta.isOpaque) return opaqueArgs(ut, rc)
    if (ut.args.size != callee.params.size)
      throw new AdaUnsupported(s"type ${callee.nameAsStr} takes ${callee.params.size} parameters")
    val pre = ListBuffer[String]()
    val args = ListBuffer[String]()
    val (ostm, oarg) = orderArg(callee, rc)
    pre ++= ostm
    oarg.foreach(args += _)
    ut.args.zip(callee.params).filter(ap => isPrimDt(ap._2.dataType)).foreach { case (a, p) =>
      val t = T(a, rc, "Arg")
      val ada = paramAda(p)
      val (code, extra) = convertArg(t, ada, p)
      val gs = t.guards ++ extra
      if (gs.isEmpty) args += code
      else {
        val v = rc.scope.fresh("Arg")
        rc.scope.decls += s"$v : $ada;"
        pre ++= guarded(gs, List(s"$v := $code;"), rc, List(s"$v := ${defaultOf(ada)};"), init = false)
        args += v
      }
    }
    val caller = provider.nowClass
    refsOf(callee).foreach { r =>
      val dt = refTypes((callee.nameAsStr, r))
      val ada = refParamType(dt, r.source)
      val p = ParamDefSpec(callee.path, NamedIdentifier(r.raw), dt)
      if (containsRoot(r.expr) && (rootOf(callee) ne rootOf(caller)))
        unsupported(s"type ${callee.nameAsStr} of another description uses `_root`")
      val expr = liftExpr(caller, ut, callee, r.expr)
      memberDeps(caller, expr).foreach { n =>
        val j = caller.seq.indexWhere(a => idRaw(a.id) == n)
        if (j >= curSeqIdx)
          unsupported(s"`${r.source}` of type ${callee.nameAsStr} is the field `$n`, which is parsed after the field that needs it")
      }
      val t: ATr = T(expr, rc, "Arg")
      val (code, extra) = convertArg(t, ada, p)
      val gs = t.guards ++ extra
      if (gs.isEmpty) args += code
      else {
        val v = rc.scope.fresh("Arg")
        rc.scope.decls += s"$v : $ada;"
        pre ++= guarded(gs, List(s"$v := $code;"), rc, List(s"$v := ${defaultOf(ada)};"), init = false)
        args += v
      }
    }
    if (isRecursive(callee)) args += (if (callee eq caller) "This.Depth - 1" else if (classFile(callee) == classFile(caller)) "Max_Depth" else base(classFile(callee)) + ".Max_Depth")
    (pre.toList, args.toList)
  }

  /** The call of the parser of the type from a type that contains itself: it asks for levels that are left. */
  private def selfGuard(ut: UserType, call: List[String], target: String, rc: RC): List[String] =
    if (!(ut.classSpec.get eq provider.nowClass) || !isRecursive(ut.classSpec.get)) call
    else
      List("if This.Depth > 0 then") ++ ind(call) ++ List("else") ++
        ind(List(failStmt(rc, "Limit_Exceeded"), s"$target := (others => <>);")) ++ List("end if;")

  private def userCall(ut: UserTypeInstream, target: String, rc: RC): List[String] = {
    val (pre, args) = callArgs(ut, rc)
    selfGuard(ut, pre ++ List(s"${qualOf(ut.classSpec.get)}Parse (${(List(target, "Buffer", rc.s) ++ args).mkString(", ")});"), target, rc)
  }

  private def userCallSub(ut: UserTypeFromBytes, target: String, rc: RC): List[String] = {
    if (ut.process.isDefined) throw new AdaUnsupported("`process`")
    val (pre, args) = callArgs(ut, rc)
    val sub = rc.scope.fresh("Sub")
    rc.scope.decls += s"$sub : ${KS}Stream;"
    val mk = ut.bytes match {
      case BytesLimitType(size, None, false, None, None) =>
        val t = T(size, rc, "Size")
        if (t.guards.isEmpty) List(s"${KS}Substream (Buffer, ${rc.s}, ${sizeCode(t)}, $sub);")
        else {
          rc.scope.needsInit = true
          List(s"if ${conjoin(t.guards)} then", s"   ${KS}Substream (Buffer, ${rc.s}, ${sizeCode(t)}, $sub);", "else",
            "   " + failStmt(rc, "Arithmetic_Error"), s"   ${KS}Substream (Buffer, ${rc.s}, 0, $sub);", "end if;")
        }
      case BytesEosType(None, false, None, None) =>
        List(s"${KS}Substream (Buffer, ${rc.s}, ${KS}Remaining (${rc.s}), $sub);")
      case bt =>
        // the bytes are cut at their terminator or padding; the value is parsed from what is left
        val raw = rc.scope.fresh("Raw")
        rc.scope.decls += s"$raw : ${KT}Slice;"
        readBytes(bt, raw, rc, defaultTarget = true) ++ List(s"$sub := ${KS}Open (Buffer, $raw);")
    }
    // the substream of cut bytes does not know that the stream has failed before: the value is not valid then
    val cut = ut.bytes match {
      case BytesLimitType(_, None, false, None, None) | BytesEosType(None, false, None, None) => false
      case _ => true
    }
    val none = if (cut) rc.scope.fresh("None") else ""
    if (cut) rc.scope.decls += s"$none : ${userPkg(ut)}.T;"
    val reset = if (cut) List(s"if not ${KS}OK (${rc.s}) then", s"   $target := $none;", "end if;") else Nil
    selfGuard(ut, pre ++ mk ++ List(s"${qualOf(ut.classSpec.get)}Parse (${(List(target, "Buffer", sub) ++ args).mkString(", ")});", s"${KS}Join (${rc.s}, $sub);") ++ reset, target, rc)
  }

  // ---------------------------------------------------------------- validation

  private val UnderscoreName = Ast.expr.Name(Ast.identifier(Identifier.ITERATOR))

  private def validate(v: ValidationSpec, dt: DataType, target: String, rc: RC): List[String] = {
    // A float that is infinity or not-a-number is compared as the other targets compare it (a not-a-number is
    // neither at least nor at most anything), where the comparison is the one that the description states. In
    // an expression such a float is not defined.
    val isFloat = dt.isInstanceOf[FloatMultiType]
    val wide = dt match { case FloatMultiType(w, _) => w.width == 8; case _ => false }
    val plusInf = if (wide) "16#7FF0_0000_0000_0000#" else "16#7F80_0000#"
    val minusInf = if (wide) "16#FFF0_0000_0000_0000#" else "16#FF80_0000#"
    def check(cond: Ast.expr, reason: String, nonFinite: Option[(List[String], String)] = None, role: String = "Valid"): List[String] = {
      tr.buffer = Some("Buffer")
      tr.io = Some(rc.s)
      tr.thisName = "This"
      tr.knownValid = Set()
      tr.iterator = Some((dt, target))
      tr.finiteKnown = if (isFloat && nonFinite.isDefined) Set(target) else Set()
      var t = try guard(rc.path)(tr.translate(cond)) finally { tr.iterator = None; tr.finiteKnown = Set() }
      var floatFirst = false
      // an expression with a float is evaluated by a subprogram of its own, with the test of a float that is not finite
      val nfTest = nonFinite.filter(_ => isFloat)
      val saved = tr.iterator
      tr.iterator = Some((dt, target))
      try {
        val text = (t.code :: t.guards ++ List(target) ++ nfTest.map(_._2).toList).mkString("\n")
        if (t.vt == VBool && !t.isLiteral) stepCtx(cond, text, rc, t.usesBuffer).foreach { ctx =>
          val gs = t.guards.map(ctx.sub)
          val code = ctx.sub(t.code)
          val tgt = ctx.sub(target)
          val finite = s"Kaitai.Floats.Is_Finite ($tgt)"
          val (value, defined) = nfTest match {
            case None => (code, if (gs.isEmpty) None else Some(conjoin(gs)))
            case Some((_, nf)) =>
              (s"(if not $finite then ${ctx.sub(nf)} else $code)", if (gs.isEmpty) None else Some(s"not $finite or else (${conjoin(gs)})"))
          }
          t = makeStep(role, rc, "Boolean", VBool, defined, value, "False", ctx)
          floatFirst = true
        }
      } finally tr.iterator = saved
      val test = List(s"if ${t.code} then", "   " + failStmt(rc, reason), "end if;")
      val body = nonFinite match {
        case Some(nf) if isFloat && !floatFirst => List(s"if not Kaitai.Floats.Is_Finite ($target) then") ++ ind(nf._1) ++ List("else") ++ ind(test) ++ List("end if;")
        case _ => test
      }
      // the statements only fail the stream, so that no component of This depends on the guard
      guarded(t.guards, body, rc, init = false)
    }
    def failUnless(inf: String, reason: String): Option[(List[String], String)] = {
      if (isFloat) opTypes += (if (wide) "U64" else "U32")
      Some((List(s"if $target /= $inf then", "   " + failStmt(rc, reason), "end if;"), s"$target /= $inf"))
    }
    def failAlways(reason: String): Option[(List[String], String)] = Some((List(failStmt(rc, reason)), "True"))
    def cmp(op: Ast.cmpop, e: Ast.expr) = Ast.expr.Compare(UnderscoreName, op, e)
    v match {
      case ValidationEq(e) => check(cmp(Ast.cmpop.NotEq, e), "Validation_Not_Equal", failAlways("Validation_Not_Equal"))
      case ValidationMin(e) => check(cmp(Ast.cmpop.Lt, e), "Validation_Less_Than", failUnless(plusInf, "Validation_Less_Than"), "Min")
      case ValidationMax(e) => check(cmp(Ast.cmpop.Gt, e), "Validation_Greater_Than", failUnless(minusInf, "Validation_Greater_Than"), "Max")
      case ValidationRange(lo, hi) =>
        check(cmp(Ast.cmpop.Lt, lo), "Validation_Less_Than", failUnless(plusInf, "Validation_Less_Than"), "Min") ++
          check(cmp(Ast.cmpop.Gt, hi), "Validation_Greater_Than", failUnless(minusInf, "Validation_Greater_Than"), "Max")
      case ValidationAnyOf(values) =>
        check(Ast.expr.BoolOp(Ast.boolop.And, values.map(x => cmp(Ast.cmpop.NotEq, x))), "Validation_Not_Any_Of", failAlways("Validation_Not_Any_Of"))
      case ValidationInEnum() =>
        dt match {
          case et: EnumType =>
            if (isWide(et.enumSpec.get)) unsupported("`valid: in-enum` with an enumeration that has a value beyond 63 bits")
            val t = fromValueChecked(dt, target, rc)
            val chk = s"${enumTypeName(et.enumSpec.get).split('.').dropRight(1).mkString(".")}"
            val isFn = (if (chk.isEmpty) "" else chk + ".") + "Is_" + enumTy(et.enumSpec.get)
            guarded(t.guards, List(s"if not $isFn (${t.code}) then", "   " + failStmt(rc, "Validation_Not_In_Enum"), "end if;"), rc, init = false)
          case _ => throw new AdaUnsupported("`in-enum` on something that is not an enumeration")
        }
      case ValidationExpr(Ast.expr.Compare(l, Ast.cmpop.NotEq, r)) =>
        // the failure is `l == r`; not `not (not Equal (...))`
        check(Ast.expr.Compare(l, Ast.cmpop.Eq, r), "Validation_Expr")
      case ValidationExpr(e) =>
        check(Ast.expr.UnaryOp(Ast.unaryop.Not, e), "Validation_Expr")
    }
  }

  private def fromValueChecked(dt: DataType, code: String, rc: RC): ATr = guard(rc.path)(tr.fromValue(dt, code, Nil))

  // --------------------------------------------------------------- compiling

  override def compile: CompileLog.SpecSuccess = {
    if (config.readWrite)
      allClasses.find(c => classFile(c) == classFile(topClass) && isRecursive(c)).foreach { c =>
        fail(c.path, s"`--read-write` for type ${c.nameAsStr}, which contains itself")
      }
    if (topClass.meta.isOpaque)
      fail(topClass.path, "opaque types")
    if (topAdaName == "Kaitai" || Reserved.contains(topAdaName.toLowerCase) || topAdaName.contains("__"))
      fail(topClass.meta.path ++ List("id"), s"description id `${topClass.name.head}` is a reserved name in Ada")
    checkRecursion()
    checkParentKey()
    checkBitStart()
    checkBitOrder()
    checkForeign()
    refsOf(topClass)
    val (spec, body) = genClass(topClass)
    val srcName = topClass.fileName.map(f => new java.io.File(f).getName).getOrElse(topClass.name.head + ".ksy")
    val header = List(s"--  Generated by the Kaitai Struct compiler from $srcName.  Do not edit.", "")
    val specImports = importedWiths(spec)
    val specText = header ++ specImports ++ withClauses(spec, Nil) ++ spec
    val specSet = usedLibs(spec.mkString("\n"))
    val bodyText = header ++ importedWiths(body, specImports) ++ withClauses(body, specSet.toList) ++ body
    val file = topClass.name.head
    CompileLog.SpecSuccess(
      "",
      List(
        CompileLog.FileSuccess(s"${file}.ads", specText.mkString("\n") + "\n"),
        CompileLog.FileSuccess(s"${file}.adb", bodyText.mkString("\n") + "\n")
      )
    )
  }

  /** The names that a caller gives `Parse` between the stream and the result */
  private def parseArgNames(cs: ClassSpec): List[String] =
    (if (hasOrderParam(cs)) List("Order") else Nil) ++ keptParams(cs).map(p => paramName(idRaw(p.id))) ++
      refsOf(cs).map(_.adaName) ++ (if (isRecursive(cs)) List("Depth") else Nil)

  /** A call as lines of code in a comment: one line, or the name and then the arguments */
  private def callLines(name: String, args: List[String]): List[String] = {
    val one = s"$name (${args.mkString(", ")});"
    if (one.length <= 90) List(one)
    else name :: wrapText(s"(${args.mkString(", ")});", 80).map("  " + _)
  }

  /** What the description is: its name, its title, and the `doc` and `doc-ref` of its top-level type */
  private def parserItems: List[Item] = {
    val cs = topClass
    val title = cs.meta.title.map(sanitize(_).trim.replaceAll("\\s+", " ")).filter(_.nonEmpty)
    val doc = docItems(cs.doc) ++ refItems(cs.doc)
    List(P(s"Parser for ${q(cs.name.head)}${title.map(t => ": " + t.stripSuffix(".")).getOrElse("")}.")) ++
      (if (doc.isEmpty) Nil else Gap :: doc)
  }

  /**
    * The comment of the library-level package: what the description is, and how to use the parser. It is the first
    * thing after the `is` of the package, which is where GNATdoc looks for the description of a package before it
    * takes the comment at the top of the file: with the comment at the top, GNATdoc took the comment of the first
    * declaration after the `use type` clauses for that of the package.
    */
  private def libraryDoc: List[String] = {
    val cs = topClass
    val pkg = topAdaName
    val args = parseArgNames(cs).map(n => if (n == "Depth") s"$pkg.Max_Depth" else n)
    val belongs = hasBelongs(cs)
    val code = ListBuffer[String]()
    code += "S : Kaitai.Streams.Stream := Kaitai.Streams.Open (Buffer);"
    code += s"V : $pkg.T;"
    code += "..."
    code ++= callLines(s"$pkg.Parse", List("V", "Buffer", "S") ++ args)
    code ++= List(s"if $pkg.Valid (V) then", "   --  read V with the functions below", "else",
      "   --  Kaitai.Streams.Status (S) tells why the data were not accepted", "end if;")
    val items = ListBuffer[Item]()
    items ++= parserItems
    items += Gap
    items += P("Use, where Buffer is the data (a Kaitai.Types.Bytes):")
    val out = ListBuffer[String]()
    out ++= render(items.toList, 3)
    out += "--"
    code.foreach(l => out += "--     " + l)
    val tail = ListBuffer[Item]()
    if (belongs)
      tail ++= List(Gap, P("V does not hold byte arrays, strings and repetitions but says where they are in Buffer. Buffer must stay unchanged while V is used, and the functions and procedures that take a buffer must be given the same one."))
    val foreign = foreignPackagesOf(allClasses.filter(c => classFile(c) == classFile(topClass)))
    if (foreign.nonEmpty)
      tail ++= List(Gap, P(s"This parser calls ${if (foreign.size == 1) "a package" else "packages"} that ${if (foreign.size == 1) "is" else "are"} written by hand: ${foreign.mkString(", ")}. The section \"Foreign code\" of docs/codegen.md says what ${if (foreign.size == 1) "it has" else "they have"} to provide."))
    tail ++= List(Gap, P("Nothing here allocates memory or raises an exception" +
      (if (foreign.isEmpty) "." else s", as long as ${if (foreign.size == 1) "that package keeps" else "those packages keep"} to that contract.")))
    if (config.readWrite) {
      val wr = ListBuffer[String]()
      wr += "W : Kaitai.Writers.Writer := Kaitai.Writers.Open (Target);"
      wr ++= callLines(s"$pkg.Write", List("V") ++ (if (belongs) List("Buffer") else Nil) ++ List("Target", "W"))
      wr ++= List("if Kaitai.Writers.OK (W) then", "   --  Kaitai.Writers.Written (W) is the part of Target that holds the bytes",
        "else", "   --  Kaitai.Writers.Status (W) tells why they could not be written", "end if;")
      tail ++= List(Gap, P("Write, which the compiler generates because of --read-write, puts a valid value back into bytes:"))
      out ++= render(tail.toList, 3)
      out += "--"
      wr.foreach(l => out += "--     " + l)
    } else out ++= render(tail.toList, 3)
    out.toList
  }

  /** `with` clauses for the packages of other descriptions that the lines use and that are not named yet */
  private def importedWiths(lines: List[String], known: List[String] = Nil): List[String] = {
    val clean = lines.map(l => l.takeWhile(_ != '-')).mkString("\n")
    val ws = (classSpecs.keys.toList.filter(_ != topClass.name.head).map(base) ++ foreignPackages).sorted.distinct
      .filter(p => ("\\b" + java.util.regex.Pattern.quote(p) + "\\.").r.findFirstIn(clean).isDefined)
      .map(p => s"with $p;").filterNot(known.contains)
    if (ws.isEmpty) Nil else ws
  }

  private val LibPackages = List("Streams", "Types", "Arithmetic", "Decoding", "Strings", "Byte_Arrays", "Floats", "Float_Arithmetic", "Processing", "Zlib", "Writers")

  private def usedLibs(text: String): Set[String] = {
    val clean = text.split("\n").map(l => l.takeWhile(_ != '-')).mkString("\n")
    LibPackages.filter(p => clean.contains(s"Kaitai.$p.")).toSet
  }

  private def withClauses(lines: List[String], alreadyInSpec: List[String]): List[String] = {
    val used = usedLibs(lines.mkString("\n")).filterNot(alreadyInSpec.contains)
    val ws = LibPackages.filter(used.contains).map(p => s"with Kaitai.$p;")
    if (ws.isEmpty) Nil else ws :+ ""
  }

  private val opTypes = mutable.Set[String]()
  /** Repeated fields (their paths) whose element procedure takes the number of the element, `_index` */
  private val indexUsers = mutable.Set[String]()

  private val UseTypes = List("U8", "U16", "U32", "U64", "S8", "S16", "S32", "S64", "Length", "Slice", "Status_Kind", "Byte_Order")

  /** Generates specification and body of a class, as lines of a library unit or a nested package. */
  private def genClass(cs: ClassSpec): (List[String], List[String]) = {
    if (cs.meta.isOpaque) fail(cs.path, s"opaque type ${cs.nameAsStr}")
    val isTop = cs.upClass.isEmpty && cs.name.size == 1
    level = cs.name.size - 1
    val pkgName = if (isTop) topAdaName else typePkg(cs.name.last)
    val specB = ListBuffer[String]()
    val bodyB = ListBuffer[String]()

    if (isTop && allClasses.exists(c => classFile(c) == classFile(topClass) && isRecursive(c))) {
      specB ++= wrapComment(
        "How deep values of a type that contains itself may be nested. Every level takes room on the stack while it is parsed, and nothing checks on a light run-time library that the stack is large enough."
      )
      specB += s"Max_Depth : constant := ${config.adaMaxDepth};"
      specB += ""
    }

    // enumerations
    cs.enums.values.foreach { e => specB ++= genEnum(e); specB += "" }

    // nested types
    val children = orderedChildren(cs)
    val childOut = children.map { c =>
      val (s, bd) = genClass(c)
      (c, s, bd)
    }
    childOut.foreach { case (_, s, _) =>
      specB ++= s
      specB += ""
    }

    level = cs.name.size - 1
    provider.nowClass = cs
    val o = new Out
    stepOut = o
    val sc = new Scope
    genMembers(cs, o, sc)

    // ---- T and its public interface
    val orderPar = if (hasOrderParam(cs)) List(s"Order : ${KT}Byte_Order") else Nil
    val paramDecls = keptParams(cs).map(p => s"${paramName(idRaw(p.id))} : ${guard(p.path)(paramAda(p))}")
    val refDecls = refsOf(cs).map(r => s"${r.adaName} : ${refParamType(refTypes((cs.nameAsStr, r)), r.source)}")
    val depthDecl = if (isRecursive(cs)) List("Depth : Natural") else Nil
    val parseParams = (List("This : out T", s"Buffer : ${KT}Bytes", s"S : in out ${KS}Stream") ++ orderPar ++ paramDecls ++ refDecls ++ depthDecl).mkString("; ")
    val belongsOk = hasBelongs(cs)
    val writeParams = "This : T; " + (if (belongsOk) s"Buffer : ${KT}Bytes; " else "") + s"Target : in out ${KT}Bytes; W : in out ${KW}Writer"

    val tName = q(cs.nameAsStr)
    specB ++= render(List(P(sentences(List(
      s"A parsed $tName",
      "A variable that Parse has not filled is not valid (see Valid)",
      "It has no pointers and can be copied and kept freely" +
        (if (belongsOk) "; it refers to the buffer it was parsed from, which must not change while it is used" else "")
    )))))
    specB += "type T is private;"
    specB += ""
    specB ++= render(List(P(sentences(List(
      "True if This is the result of a Parse that succeeded",
      "The accessors below require it" + (if (config.readWrite) ", and so does Write" else "")
    )))))
    specB += "function Valid (This : T) return Boolean;"
    specB += ""
    if (belongsOk) {
      specB ++= render(List(P(sentences(List(
        "True if everything that This refers to lies within Buffer",
        "It holds for the buffer that This was parsed from",
        "The operations below that take a buffer require it, for This or for a position taken from This; give them that same buffer"
      )))))
      specB += s"function Belongs_To (This : T; Buffer : ${KT}Bytes) return Boolean;"
      specB += ""
    }
    specB ++= parseDoc(cs, isTop, o, belongsOk)
    specB += s"procedure Parse ($parseParams)"
    specB += "with"
    specB += s"  Pre  => ${KS}Is_Valid (S, Buffer)" +
      (if (needsAlign(cs)) s"\n and then (if ${KS}OK (S) then ${KS}Bits_Left (S) = 0)," else ",")
    specB += s"  Post => ${KS}Is_Valid (S, Buffer) and then ${KS}Advanced (S'Old, S) and then Valid (This) = ${KS}OK (S)" +
      (if (belongsOk) " and then Belongs_To (This, Buffer)" else "") + (if (isRecursive(cs)) "," else ";")
    if (isRecursive(cs)) specB += "  Subprogram_Variant => (Decreases => Depth, Decreases => 1);"
    specB += ""
    specB ++= o.pub
    if (config.readWrite) {
      specB ++= ind(writeDoc(belongsOk))
      specB += s"   procedure Write ($writeParams)"
      specB += "   with"
      specB += s"     Pre  => Valid (This) and then ${if (belongsOk) "Belongs_To (This, Buffer) and then " else ""}${KW}Is_Valid (W, Target),"
      specB += s"     Post => ${KW}Is_Valid (W, Target) and then ${KW}Same_Window (W'Old, W);"
      specB += ""
    }
    specB += "private"
    specB += ""
    specB ++= ind(o.privTypes.toList)
    // record
    val ioComp = if (hasIo(cs)) List(s"Io : ${KS}Stream;") else Nil
    val orderComp = if (storesOrder(cs)) List(s"Order : ${KT}Byte_Order := ${KT}Little_Endian;") else Nil
    val paramComps = keptParams(cs).flatMap(p => paramComponent(p))
    val refComps = refsOf(cs).map { r =>
      val t = refParamType(refTypes((cs.nameAsStr, r)), r.source)
      s"${r.adaName} : $t := ${defaultOf(t)};"
    }
    val depthComp = if (isRecursive(cs)) List("Depth : Natural := 0;") else Nil
    val comps = List("Is_Valid : Boolean := False;") ++ ioComp ++ orderComp ++ paramComps ++ refComps ++ depthComp ++ o.comps.toList
    specB += "   type T is record"
    specB ++= ind(comps, 2)
    specB += "   end record;"
    specB += ""
    val validTerms = (List("This.Is_Valid") ++ o.valid.toList)
    specB += "   function Valid (This : T) return Boolean"
    specB += s"   is (${validTerms.mkString("\n and then ")});"
    specB += ""
    if (belongsOk) {
      val ioTerm = if (hasIo(cs)) List(s"${KS}Is_Valid (This.Io, Buffer)") else Nil
      val bt = ioTerm ++ o.belongs.toList
      specB += s"   function Belongs_To (This : T; Buffer : ${KT}Bytes) return Boolean"
      specB += s"   is (${if (bt.isEmpty) "True" else bt.mkString("\n and then ")});"
      specB += ""
    }
    keptParams(cs).foreach(p => specB ++= genParamAccessor(p, cs))
    specB ++= ind(o.privFuncs.toList)
    // ---- Parse body
    val bodyParse = genParseBody(cs, o, sc, parseParams)

    val specOut = ListBuffer[String]()
    if (isTop) {
      specOut += s"package $pkgName"
      specOut += "  with SPARK_Mode, Always_Terminates"
      specOut += "is"
      specOut += ""
      specOut ++= ind(libraryDoc)
      specOut += ""
      val needed = UseTypes.filter(t => opTypes.contains(t) || tr.ops.contains(t))
      needed.foreach(t => specOut += s"   use type $KT$t;")
      val orderUse = tr.ops.contains("Byte_Arrays.Order")
      if (orderUse) specOut += "   use type Kaitai.Byte_Arrays.Order;"
      if (needed.nonEmpty || orderUse) specOut += ""
      specOut ++= ind(specB.toList)
      specOut += ""
      specOut += s"end $pkgName;"
    } else {
      specOut ++= packageDoc(cs)
      specOut += s"package $pkgName is"
      specOut += ""
      specOut ++= ind(specB.toList)
      specOut += ""
      specOut += s"end $pkgName;"
    }

    val bodyOut = ListBuffer[String]()
    bodyB ++= o.bodyConsts
    if (o.bodyConsts.nonEmpty) bodyB += ""
    childOut.foreach { case (_, _, bd) => bodyB ++= bd; bodyB += "" }
    bodyB ++= o.steps
    bodyB ++= o.bodyBefore
    bodyB ++= bodyParse
    bodyB += ""
    bodyB ++= o.bodyAfter
    if (config.readWrite) {
      val text = o.write.mkString("\n")
      val unused = List("Buffer" -> belongsOk, "This" -> true, "Target" -> true, "W" -> true).collect {
        case (n, true) if !("\\b" + n + "\\b").r.findFirstIn(text).isDefined => n
      }
      val warn = unused.map(n => s"pragma Warnings (Off, $n);")
      bodyB += s"procedure Write ($writeParams) is"
      bodyB ++= ind(o.wscope.decls.toList ++ warn)
      bodyB += "begin"
      bodyB ++= ind(if (o.write.isEmpty) List("null;") else o.write.toList)
      bodyB += "end Write;"
      bodyB += ""
    }
    if (isTop) {
      bodyOut += s"package body $pkgName"
      bodyOut += "  with SPARK_Mode"
      bodyOut += "is"
    } else bodyOut += s"package body $pkgName is"
    bodyOut += ""
    bodyOut ++= ind(expandStepCalls(bodyB.toList))
    bodyOut += ""
    bodyOut += s"end $pkgName;"
    stepOut = null
    (specOut.toList.map(_.replaceAll("\\s+$", "")), bodyOut.toList.map(_.replaceAll("\\s+$", "")))
  }

  /** The comment of a package that a nested type becomes */
  private def packageDoc(cs: ClassSpec): List[String] = {
    val indent = 3 * level
    val head = render(List(P(s"The type ${q(cs.name.last)} of the description (${q(cs.nameAsStr)})")), indent)
    val d = docItems(cs.doc) ++ refItems(cs.doc)
    head ++ (if (d.isEmpty) Nil else "--" :: render(d, indent))
  }

  /** The comment of `Parse`: what it does, what it leaves, and the tags of its parameters */
  private def parseDoc(cs: ClassSpec, isTop: Boolean, o: Out, belongsOk: Boolean): List[String] = {
    val items = ListBuffer[Item]()
    items += P(s"Parses one ${q(cs.nameAsStr)} at the position of S and leaves S behind it.")
    items += Gap
    items += P("It does not raise an exception. If the data are not accepted (for example they end too early, or a fixed content or a `valid` of the description does not hold), S has failed afterwards, Kaitai.Streams.Status (S) is the reason and This is not valid. If S had failed before the call, nothing is read and This is not valid.")
    if (isTop) {
      items += Gap
      items += P("Bytes that follow the value are not an error. Kaitai.Streams.Is_EOF (S) tells whether everything was read.")
    }
    if (o.kept.nonEmpty) {
      items += Gap
      items += P(s"Parsed here once, where an expression of the description first needs them, and kept in This: ${o.kept.mkString(", ")}.")
    }
    if (o.rereads.nonEmpty || o.unread.nonEmpty) {
      items += Gap
      items += P(List(
        if (o.rereads.isEmpty) "" else s"Not kept in This, but read again when asked for (Parse has gone over them once and checked them): ${o.rereads.mkString(", ")}",
        if (o.unread.isEmpty) "" else s"Not looked at here at all, so that an error in them shows only when they are asked for: ${o.unread.mkString(", ")}"
      ).filter(_.nonEmpty).map(endSentence).mkString(" "))
    }
    if (needsAlign(cs)) {
      items += Gap
      items += P("S must be at a byte boundary (Kaitai.Streams.Bits_Left (S) = 0) unless it has failed. That holds for a stream that was just opened and after a read of whole bytes, such as an integer or a byte array.")
    }
    items += Gap
    val tags = ListBuffer[String]()
    tags ++= tag("param", "This", "The result. Valid if and only if S has not failed")
    tags ++= tag("param", "Buffer", "The data. S must be a stream on it (Kaitai.Streams.Is_Valid (S, Buffer))")
    tags ++= tag("param", "S", "Where to read. Afterwards it is at the position behind the value, or it has failed")
    if (hasOrderParam(cs)) {
      val why = cs.meta.endian match {
        case Some(_: CalcEndian) => "The `endian` of the type is calculated from `_parent`, so the parser of the parent computes it and passes it"
        case _ => "The type inherits a calculated `endian` from its parent, so the parser of the parent passes its own"
      }
      tags ++= tag("param", "Order", s"The byte order of the integers of this value. $why")
    }
    keptParams(cs).foreach { p =>
      val d = oneLine(p.doc)
      tags ++= tag("param", paramName(idRaw(p.id)), s"Parameter ${q(idRaw(p.id))} of the type" + (if (d.isEmpty) "" else ": " + d.mkString(" ")))
    }
    refsOf(cs).foreach { r =>
      val chain = chainOf(r.expr)
      val text = chain match {
        case Some((Identifier.ROOT, _)) => s"The value of ${q(r.source)}, passed down from the top-level value"
        case Some((Identifier.PARENT, attrs)) if !attrs.contains(Identifier.IO) && attrs.takeWhile(_ == Identifier.PARENT).isEmpty =>
          s"The value of ${q(r.source)}: the caller is the parser of the value that this one is part of and passes its own ${q(attrs.mkString("."))}"
        case Some((Identifier.PARENT, attrs)) if !attrs.contains(Identifier.IO) =>
          val hops = 1 + attrs.takeWhile(_ == Identifier.PARENT).size
          s"The value of ${q(r.source)}: the caller passes what it has itself as ${q((List.fill(hops - 1)("_parent") ++ attrs.drop(hops - 1)).mkString("."))}"
        case _ =>
          s"The value of ${q(r.source)}: the caller computes it, from the arguments that it gives for the parameters of the type and from what it has itself, and passes it"
      }
      tags ++= tag("param", r.adaName, text)
    }
    if (isRecursive(cs))
      tags ++= tag("param", "Depth", "How many levels of values of this type may be nested inside this one. Pass Max_Depth. A nested value is parsed with Depth - 1, and where Depth is 0 the stream fails with Limit_Exceeded instead")
    render(items.toList) ++ tags
  }

  /** The comment of `Write` */
  private def writeDoc(belongsOk: Boolean): List[String] = {
    val items = List(
      P("Writes This to Target, at the position of W, and leaves W behind what it wrote."),
      Gap,
      P("It does not raise an exception. If Target has not room enough, or the value cannot be written (the expression of a size is not defined, or the buffer is no longer what was parsed), W has failed afterwards, Kaitai.Writers.Status (W) is the reason (Capacity_Exceeded for lack of room) and Target may hold some of the bytes. If W had failed before the call, nothing is written. Kaitai.Writers.Written (W) is the part of Target that holds what has been written through W."),
      Gap,
      P("Parsing what was written gives the same value again, with the same fields and slices of the same contents. The output is the input again, except for what a parsed value does not keep: bytes that no field uses and skipped bits are written as zeros, bytes after a terminator in a field with a size as the terminator byte, padding as the padding byte, and instances with a position are not written.")
    )
    render(items :+ Gap) ++
      tag("param", "This", "The value to write. It must be valid") ++
      (if (belongsOk) tag("param", "Buffer", "The buffer that This was parsed from, unchanged. What This refers to is written from it") else Nil) ++
      tag("param", "Target", "Where the bytes go. W must be a writer over it (Kaitai.Writers.Is_Valid (W, Target))") ++
      tag("param", "W", "Where to write in Target, for example Kaitai.Writers.Open (Target). Afterwards it is behind the bytes written, or it has failed")
  }

  private def paramComponent(p: ParamDefSpec): List[String] = {
    val t = guard(p.path)(paramAda(p))
    List(s"${plain(idRaw(p.id))} : $t := ${defaultOf(t)};")
  }

  private def genParamAccessor(p: ParamDefSpec, cs: ClassSpec): List[String] = Nil

  // enumerations

  /** An enumeration with a value that is above the largest S64: its functions take a U64 */
  private def isWide(e: EnumSpec): Boolean = e.map.keys.exists(_ > AdaTranslator.S64Max)

  private def genEnum(e: EnumSpec): List[String] = {
    val n = enumTy(e)
    val entries = e.map.toList
    val wide = isWide(e)
    entries.foreach { case (v, _) =>
      if (v < AdaTranslator.S64Min || v > AdaTranslator.U64Max || (wide && v < 0))
        fail(e.path, s"enum value $v does not fit into 64 bits" + (if (wide && v < 0) " together with values above 2**63-1" else ""))
    }
    // the functions take the integer as it was read: a U64 if a value is above the largest S64
    val intT = if (wide) KT + "U64" else KT + "S64"
    val lits = entries.map { case (_, s) => enumLit(e, s.name) }
    val values = entries.map(_._1.toString)
    val out = ListBuffer[String]()
    out ++= render(List(P(s"Enumeration ${q(e.name.last)}")))
    entries.foreach { case (v, ev) =>
      out ++= tag("enum", enumLit(e, ev.name), sentences(List(s"${q(ev.name)}, $v") ++ oneLine(ev.doc)))
    }
    out += s"type $n is (${lits.mkString(", ")});"
    out += ""
    out ++= render(List(P(s"True if Value is the number of a label of $n")))
    out += s"function Is_$n (Value : $intT) return Boolean"
    out += s"is (Value in ${values.mkString(" | ")});"
    out += ""
    out ++= render(List(P(s"The label of $n that has the number Value")))
    out += s"function To_$n (Value : $intT) return $n"
    if (entries.exists(_._1 < 0)) {
      // GNAT is very slow on a case with a negative choice over a 64-bit type
      opTypes += "S64"
      val chain = entries.dropRight(1).zipWithIndex.map { case ((v, s), i) =>
        s"${if (i == 0) "if" else "elsif"} Value = $v then ${enumLit(e, s.name)}"
      }
      out += s"is (${chain.mkString(" ")} else ${enumLit(e, entries.last._2.name)})"
    } else {
      val cases = entries.zipWithIndex.map { case ((v, s), i) =>
        if (i == entries.size - 1) s"when others => ${enumLit(e, s.name)}" else s"when $v => ${enumLit(e, s.name)}"
      }
      out += s"is (case Value is ${cases.mkString(", ")})"
    }
    out += s"with Pre => Is_$n (Value);"
    out += ""
    out ++= render(List(P(s"The number of a label of $n, as it is in the data")))
    out += s"function To_Integer (Value : $n) return $intT"
    if (entries.exists(_._1 < 0)) {
      val chain = entries.dropRight(1).zipWithIndex.map { case ((v, s), i) =>
        s"${if (i == 0) "if" else "elsif"} Value = ${enumLit(e, s.name)} then $v"
      }
      out += s"is (${chain.mkString(" ")} else ${entries.last._1});"
    } else {
      val cases2 = entries.map { case (v, s) => s"when ${enumLit(e, s.name)} => $v" }
      out += s"is (case Value is ${cases2.mkString(", ")});"
    }
    out.toList
  }

  // ------------------------------------------------------------------ members

  // ------------------------------------------------------------------ writing

  private def writeCtx(cs: ClassSpec, sc: Scope, path: List[String]): RC =
    RC("Unavailable_Stream", if (storesOrder(cs)) "This.Order" else "", sc, path, w = true)

  private def writeInt(dt: DataType, target: String, rc: RC): List[String] = dt match {
    case Int1Type(sg) => List(s"${KW}Write_${if (sg) "S1" else "U1"} (Target, W, $target);")
    case IntMultiType(sg, w, e) =>
      val nm = s"Write_${if (sg) "S" else "U"}${w.width}"
      e match {
        case Some(fe) => List(s"$KW$nm${fe.toSuffix} (Target, W, $target);")
        case None => List(s"$KW$nm (Target, W, ${orderOf(rc, dt)}, $target);")
      }
    case FloatMultiType(w, e) =>
      val nm = s"Write_U${w.width}"
      e match {
        case Some(fe) => List(s"$KW$nm${fe.toSuffix} (Target, W, $target);")
        case None => List(s"$KW$nm (Target, W, ${orderOf(rc, dt)}, $target);")
      }
    case BitsType1(be) =>
      List(s"${KW}Write_Bits_Int_${if (be == BigBitEndian) "Be" else "Le"} (Target, W, 1, (if $target then 1 else 0));")
    case BitsType(w, be) =>
      List(s"${KW}Write_Bits_Int_${if (be == BigBitEndian) "Be" else "Le"} (Target, W, $w, $target);")
    case EnumType(_, _, b) => writeInt(b, target, rc)
    case other => throw new AdaUnsupported(s"type $other")
  }

  /**
    * Statements that write a field of bytes that is kept as the slice `target`, so that parsing what is written
    * gives the same slice again.
    */
  private def writeBytes(bt: BytesType, target: String, rc: RC): List[String] = {
    val src = s"Buffer ($target.First .. $target.Last)"
    val none = "(1 .. 0 => 0)"
    def single(term: Seq[Byte]): Int =
      if (term.size != 1) throw new AdaUnsupported("a terminator of more than one byte") else unsignedByte(term.head)
    bt match {
      case BytesLimitType(_, None, _, None, _) => List(s"${KW}Write_Bytes (Target, W, $src);")
      case BytesLimitType(size, term, include, pad, _) =>
        val padByte = pad.getOrElse(single(term.get))
        term.foreach(single)
        val t = T(size, rc, "Size")
        val sz = sizeCode(t)
        val body =
          if (term.isDefined && pad.isDefined && !include && padByte != single(term.get) && !(t.isLiteral && t.lo == 0))
            // padding is stripped before the terminator is looked for: the terminator has to be written
            { opTypes += "Length"; List(s"${KW}Write_Bytes (Target, W, $src);", s"if ${KT}Size ($target) < $sz then",
              s"   ${KW}Write_U1 (Target, W, ${single(term.get)});",
              s"   ${KW}Write_Padded (Target, W, $none, $sz - ${KT}Size ($target) - 1, $padByte);", "end if;") }
          else List(s"${KW}Write_Padded (Target, W, $src, $sz, $padByte);")
        guarded(t.guards, body, rc)
      case BytesEosType(term, include, pad, _) =>
        term.foreach(single)
        List(s"${KW}Write_Bytes (Target, W, $src);") ++
          (if (term.isDefined && !include) {
             opTypes += "Length"
             List(s"if ${KW}Remaining (W) > 0 then", s"   ${KW}Write_U1 (Target, W, ${single(term.get)});", "end if;")
           } else Nil) ++
          pad.toList.map(p => s"${KW}Write_Padded (Target, W, $none, ${KW}Remaining (W), $p);")
      case BytesTerminatedType(term, include, consume, eosError, _) =>
        val t = single(term)
        if (include && !consume) throw new AdaUnsupported("a terminator that is included but not consumed")
        if (!include && consume && eosError) List(s"${KW}Write_Bytes_Term (Target, W, $src, $t);")
        else if (!include && consume) {
          opTypes += "Length"
          List(s"${KW}Write_Bytes (Target, W, $src);", s"if ${KW}Remaining (W) > 0 then", s"   ${KW}Write_U1 (Target, W, $t);", "end if;")
        }
        else List(s"${KW}Write_Bytes (Target, W, $src);")
      case other => throw new AdaUnsupported(s"bytes $other")
    }
  }

  /** The call of `Write` of the type of a field kept as `target` */
  private def writeCall(callee: ClassSpec, target: String, writer: String): String = {
    val buf = if (hasBelongs(callee)) "Buffer, " else ""
    s"${qualOf(callee)}Write ($target, ${buf}Target, $writer);"
  }

  private def writeValue(dt: DataType, target: String, rc: RC): List[String] = withPath(rc.path) {
    dt match {
      case _: IntType | _: EnumType | _: FloatType | _: BooleanType => writeInt(dt, target, rc)
      case bt: BytesType => writeBytes(bt, target, rc)
      case StrFromBytesType(bt, _, _) => writeBytes(bt, target, rc)
      case ut: UserTypeInstream => List(writeCall(ut.classSpec.get, target, "W"))
      case ut: UserTypeFromBytes =>
        val callee = ut.classSpec.get
        ut.bytes match {
          case BytesLimitType(size, None, false, None, None) =>
            val t = T(size, rc, "Size")
            val sub = rc.scope.fresh("Sub")
            rc.scope.decls += s"$sub : ${KW}Writer;"
            guarded(t.guards,
              List(s"${KW}Subwriter (Target, W, ${sizeCode(t)}, $sub);", writeCall(callee, target, sub), s"${KW}Join (W, $sub);"), rc)
          case BytesEosType(None, false, None, None) => List(writeCall(callee, target, "W"))
          case BytesTerminatedType(term, include, consume, eosError, _) =>
            if (term.size != 1) throw new AdaUnsupported("a terminator of more than one byte")
            if (include && !consume) throw new AdaUnsupported("a terminator that is included but not consumed")
            val t = unsignedByte(term.head)
            List(writeCall(callee, target, "W")) ++
              (if (!include && consume && eosError) List(s"${KW}Write_U1 (Target, W, $t);")
               else if (!include && consume) {
                 opTypes += "Length"
                 List(s"if ${KW}Remaining (W) > 0 then", s"   ${KW}Write_U1 (Target, W, $t);", "end if;")
               } else Nil)
          case _ => throw new AdaUnsupported("a value cut from bytes with a size and a terminator or padding")
        }
      case other => throw new AdaUnsupported(s"type $other")
    }
  }

  private def genWriteAttr(cs: ClassSpec, a: AttrSpec, first: Boolean, o: Out, rc: RC): Unit = {
    val nm = plain(idRaw(a.id))
    val bs = base(idRaw(a.id))
    def wrapIf(stmts: List[String]): List[String] =
      if (!hasCond(a)) stmts else List(s"if This.${hasNm(bs)} then") ++ ind(stmts) ++ List("end if;")
    val align =
      if (first && alignedTypes.contains(cs) && a.cond.repeat == NoRepeat && (a.dataType match {
            case _: BitsType | _: BitsType1 => true
            case EnumType(_, _, _: BitsType) => true
            case _ => false
          })) List(s"${KW}Align_To_Byte (W);")
      else Nil
    val stmts: List[String] =
      if (isContents(a)) {
        if (hasCond(a)) throw new AdaUnsupported("`contents` with a condition")
        List(s"${KW}Write_Bytes (Target, W, ${bs}_Expected);")
      } else if (AdaTranslator.hasProcess(a.dataType)) {
        if (a.cond.repeat != NoRepeat) throw new AdaUnsupported("`process` on a repeated field")
        wrapIf(a.dataType match {
          case b: BytesType => writeBytes(b, s"This.$nm", rc)
          case ut: UserTypeFromBytes => writeBytes(ut.bytes, s"This.$nm", rc)
          case _ => throw new AdaUnsupported("`process` on a string")
        })
      } else
        a.cond.repeat match {
          case NoRepeat =>
            a.dataType match {
              case st: SwitchType => wrapIf(writeSwitch(cs, a, st, nm, bs, rc))
              case dt => wrapIf(writeValue(dt, s"This.$nm", rc))
            }
          case _ => wrapIf(writeRepeat(cs, a, nm, bs, rc))
        }
    o.write ++= align ++ stmts
    if (o.write.exists(_.contains("Unavailable_Stream"))) throw new AdaUnsupported("`_io` in an expression of a field that is written")
  }

  private def writeSwitch(cs: ClassSpec, a: AttrSpec, st: SwitchType, nm: String, bs: String, rc: RC): List[String] = {
    val cases = st.cases.toList
    val elseCase = cases.find(_._1 == SwitchType.ELSE_CONST)
    if (cases.forall(c => isIntCase(c._2))) {
      if (cases.map(_._2).distinct.size != 1)
        throw new AdaUnsupported("a field whose type is an integer of different kinds, chosen by a value")
      if (elseCase.isEmpty && hasCond(a)) throw new AdaUnsupported("a field with a condition whose type depends on a value and has no else case")
      val write = writeValue(cases.head._2, s"This.$nm", rc)
      if (elseCase.isEmpty) List(s"if This.${hasNm(bs)} then") ++ ind(write) ++ List("end if;") else write
    } else {
      val variants = switchVariants(st)
      val branches = variants.flatMap { case (dt, n) =>
        List(s"when ${bs}_Is_$n =>") ++ ind(writeValue(dt, s"This.$nm.$n", rc))
      }
      List(s"case This.$nm.Kind is") ++ ind(branches ++ List(s"when ${bs}_Is_None =>", "   null;")) ++ List("end case;")
    }
  }

  private def writeRepeat(cs: ClassSpec, a: AttrSpec, nm: String, bs: String, rc: RC): List[String] = {
    val dt = a.dataType
    if (AdaTranslator.fixedElement(dt).isDefined)
      return List(s"${KW}Write_Bytes (Target, W, Buffer (This.$nm.First .. This.$nm.Last));")
    val (elT, elPkg) = dt match {
      case ut: UserType => (userPkg(ut) + ".T", qualOf(ut.classSpec.get))
      case _: BytesType | _: StrType => (KT + "Slice", "")
      case _: BitsType | _: BitsType1 | EnumType(_, _, _: BitsType) => (bitsElementType(bs, dt), "")
      case other => throw new AdaUnsupported(s"repetition of $other")
    }
    val isSlice = !dt.isInstanceOf[UserType]
    val indexed = indexUsers.contains(a.path.mkString("/"))
    tr.indexCode = if (indexed) Some("Number") else None
    val body = try writeValue(dt, "Element", rc) finally tr.indexCode = None
    // the number is kept only where what is written needs it
    val usesIndex = indexed && body.exists(_.contains("Number"))
    val cur = s"${bs}_Cursor"
    val write =
      if (isSlice) body
      else List(s"if ${elPkg}Valid (Element) then") ++ ind(body) ++ List("else", "   --  The buffer is not what was parsed",
        s"   ${KW}Fail (W, ${KT}Validation_Expr);", "end if;")
    // As in Parse: an element that neither read nor wrote anything ends the loop, since all that follow do the same.
    val idle = a.cond.repeat.isInstanceOf[RepeatExpr] && mayBeEmpty(dt) && !indexed
    val (idleDecls, idleBefore, idleExit) =
      if (!idle) (Nil, Nil, Nil)
      else (
        List(s"   Read_At  : ${KS}Stream;", s"   Write_At : ${KW}Writer;"),
        List("   Read_At := Position.Io;", "   Write_At := W;"),
        List("   --  An element that read nothing and wrote nothing: so will all that follow",
          s"   exit when ${KS}Pos (Position.Io) = ${KS}Pos (Read_At) and then ${KS}Bits_Left (Position.Io) = ${KS}Bits_Left (Read_At)",
          s"     and then ${KW}Pos (W) = ${KW}Pos (Write_At) and then ${KW}Bits_Free (W) = ${KW}Bits_Free (Write_At);"))
    List("declare", s"   Position : $cur := ${bs}_First (This);", s"   Element  : $elT;") ++
      (if (usesIndex) List(s"   Number   : ${KT}Length;") else Nil) ++ idleDecls ++ List("begin") ++
      ind(List(
        "while Has_Element (Position) loop",
        "   pragma Loop_Invariant (Belongs_To (Position, Buffer));",
        s"   pragma Loop_Invariant (${KW}Is_Valid (W, Target) and then ${KW}Same_Window (W'Loop_Entry, W));",
        "   pragma Loop_Variant (Decreases => Remaining (Position));") ++ idleBefore ++ List(
        ) ++ (if (usesIndex) List("   Number := Position.Index;") else Nil) ++ List(
        "   Next (This, Buffer, Position, Element);") ++ ind(write) ++ idleExit ++ List("end loop;")) ++ List("end;")
  }

  private def genMembers(cs: ClassSpec, o: Out, sc: Scope): Unit = {
    val rc = RC("S", if (storesOrder(cs)) "Order" else "", sc, cs.path)
    // parameters
    keptParams(cs).foreach { p => guard(p.path)(genParamMember(p, cs, o, rc)) }
    certain.clear(); flagged.clear(); plan = Plan()
    if (config.readWrite) keptOf(cs).headOption.foreach { p =>
      fail(p.path, s"`Write` of a type whose `seq` needs the parse instance `${idRaw(p.id)}`: the instance is not written (instances with a position are not), so what is written would not agree with the count, size or condition that was computed from it")
    }
    // sequence
    cs.seq.zipWithIndex.foreach { case (a, i) =>
      val rcA = rc.copy(path = a.path)
      curSeqIdx = i
      guard(a.path)(planAttr(cs, a, i, rcA))
      preTaken = 0
      loopTaken = false
      guard(a.path)(genSeqAttr(cs, a, i == 0, o, rcA))
      // a generator that does not place the reads would let an expression use an instance that was never read
      if (plan.pre.nonEmpty && preTaken != 1 || plan.loop.nonEmpty && !loopTaken)
        fail(a.path, s"the field `${idRaw(a.id)}` needs a parse instance, and this kind of field has no place to read it")
      if (config.readWrite) guard(a.path)(genWriteAttr(cs, a, i == 0, o, writeCtx(cs, o.wscope, a.path)))
    }
    // instances
    curSeqIdx = Int.MaxValue
    cs.instances.values.foreach { inst =>
      provider.nowClass = cs
      inst match {
        case v: ValueInstanceSpec => guard(v.path)(genValueInstance(cs, v, o))
        case p: ParseInstanceSpec =>
          if (isKept(cs, p)) guard(p.path)(genKeptInstance(cs, p, o)) else guard(p.path)(genParseInstance(cs, p, o))
      }
    }
    plan = Plan()
    provider.nowClass = cs
  }

  private def accessor(
    o: Out,
    name: String,
    ret: String,
    pre: String,
    post: Option[String],
    body: String,
    params: String = "This : T",
    comment: List[String] = Nil
  ): Unit = {
    o.pub ++= ind(comment, 1)
    o.pub += s"   function $name ($params) return $ret"
    o.pub += s"   with Pre => $pre${post.map(p => s", Post => $p").getOrElse("")};"
    o.pub += ""
    o.privFuncs += s"function $name ($params) return $ret"
    o.privFuncs += s"is ($body);"
    o.privFuncs += ""
  }

  private def genParamMember(p: ParamDefSpec, cs: ClassSpec, o: Out, rc: RC): Unit = {
    val nm = plain(idRaw(p.id))
    val bs = base(idRaw(p.id))
    val ada = guard(p.path)(paramAda(p))
    p.dataType match {
      case et: EnumType =>
        enumAccessors(o, nm, bs, ada, et, "Valid (This)", s"Parameter ${q(idRaw(p.id))}", "as the integer that was given to Parse",
          "The integer", p.doc, Nil)
      case _ =>
        accessor(o, nm, ada, "Valid (This)", None, s"This.$nm",
          comment = describe(List(s"Parameter ${q(idRaw(p.id))} of the type, as it was given to Parse"), p.doc))
    }
  }

  /**
    * The pair of accessors of an enumeration: the integer, `X_Value`, and the label, `X`. `subject` names what it is
    * (Field `kind`), `valueIs` what the integer is, `integer` how the integer is named in the sentence about the label.
    */
  private def enumAccessors(o: Out, nm: String, bs: String, ada: String, et: EnumType, pre: String, subject: String, valueIs: String,
                            integer: String, doc: DocSpec, requires: List[String], compName: Option[String] = None): Unit = {
    val comp = compName.getOrElse(nm)
    val spec = et.enumSpec.get
    val tyName = enumTypeName(spec)
    val pkgPrefix = tyName.split('.').dropRight(1).mkString(".")
    val q = if (pkgPrefix.isEmpty) "" else pkgPrefix + "."
    if (isWide(spec)) {
      // the integer is an unsigned one and goes to the functions as a U64
      if (!Set("U8", "U16", "U32", "U64").contains(ada.stripPrefix(KT)))
        throw new AdaUnsupported(s"enumeration ${spec.name.last} with a value beyond 63 bits on something that is not an unsigned integer")
      def asU64(x: String) = if (ada == KT + "U64") x else s"${KT}U64 ($x)"
      accessor(o, s"${bs}_Value", ada, pre, None, s"This.$comp", comment = describe(List(s"$subject $valueIs"), DocSpec.EMPTY, requires))
      accessor(o, nm, tyName, s"$pre and then ${q}Is_${enumTy(spec)} (${asU64(s"${bs}_Value (This)")})", None,
        s"${q}To_${enumTy(spec)} (${asU64(s"This.$comp")})", comment = labelComment(subject, tyName, q, spec, bs, integer, doc, requires))
      return
    }
    val t = guard(Nil)(tr.fromValue(et, s"${bs}_Value (This)", Nil))
    accessor(o, s"${bs}_Value", ada, pre, None, s"This.$comp", comment = describe(List(s"$subject $valueIs"), DocSpec.EMPTY, requires))
    val enumPre = (List(pre) ++ t.guards ++ List(s"${q}Is_${enumTy(spec)} (${t.code})")).mkString(" and then ")
    accessor(o, nm, tyName, enumPre, None, s"${q}To_${enumTy(spec)} (${t.code.replace(s"${bs}_Value (This)", s"This.$comp")})",
      comment = labelComment(subject, tyName, q, spec, bs, integer, doc, requires))
  }


  private def labelComment(subject: String, tyName: String, q: String, spec: EnumSpec, bs: String, integer: String, doc: DocSpec,
                           requires: List[String]): List[String] =
    describe(List(s"$subject as a label of $tyName"), doc,
      List(s"$integer need not be the number of a label: this function requires ${q}Is_${enumTy(spec)} of ${bs}_Value") ++ requires)

  // ----------------------------------------------------------------- seq attrs

  private def hasCond(a: AttrLikeSpec): Boolean = a.cond.ifExpr.isDefined

  private def wrapCond(a: AttrSpec, hasName: Option[String], stmts: List[String], rc: RC): List[String] = {
    preTaken += 1
    plan.pre ++ wrapCond0(a, hasName, stmts, rc)
  }

  private def wrapCond0(a: AttrSpec, hasName: Option[String], stmts: List[String], rc: RC): List[String] =
    a.cond.ifExpr match {
      case None => stmts
      case Some(c) =>
        val t = T(c, rc, "If")
        val inner = hasName.map(h => s"This.$h := True;").toList ++ stmts
        if (t.isLiteral && t.vt == VBool && t.code == "True") return inner
        rc.scope.needsInit = true
        if (t.isLiteral && t.vt == VBool) return Nil
        val ifs = List(s"if ${t.code} then") ++ ind(inner) ++ List("end if;")
        if (t.guards.isEmpty) ifs
        else List(s"if ${conjoin(t.guards)} then") ++ ind(ifs) ++ List("else", "   " + failStmt(rc, "Arithmetic_Error"), "end if;")
    }

  private def condParts(cs: ClassSpec, a: AttrSpec, o: Out): (String, String) = {
    val bs = base(idRaw(a.id))
    if (hasCond(a)) {
      o.comps += s"${hasNm(bs)} : Boolean := False;"
      o.pub ++= ind(describe(List(s"True if the field ${q(idRaw(a.id))} is there", "It has a condition (`if`) in the description, which Parse evaluated"),
        DocSpec.EMPTY) ++ List(s"function ${hasNm(bs)} (This : T) return Boolean", "with Pre => Valid (This);", ""))
      o.privFuncs += s"function ${hasNm(bs)} (This : T) return Boolean"
      o.privFuncs += s"is (This.${hasNm(bs)});"
      o.privFuncs += ""
      (s"Valid (This) and then ${hasNm(bs)} (This)", s"${hasNm(bs)}")
    } else ("Valid (This)", "")
  }

  private def validWrap(a: AttrSpec, term: String): String =
    if (hasCond(a)) s"(if This.${hasNm(base(idRaw(a.id)))} then $term)" else term

  private def genSeqAttr(cs: ClassSpec, a: AttrSpec, first: Boolean, o: Out, rc: RC): Unit = {
    val nm = plain(idRaw(a.id))
    val bs = base(idRaw(a.id))
    val firstAlign =
      if (first && alignedTypes.contains(cs) && a.cond.repeat == NoRepeat && (a.dataType match {
            case _: BitsType | _: BitsType1 => true
            case EnumType(_, _, _: BitsType) => true
            case _ => false
          }))
        List(s"${KS}Align_To_Byte (S);")
      else Nil
    if (isContents(a)) {
      val bytes = a.valid.get.asInstanceOf[ValidationEq].value.asInstanceOf[Ast.expr.List].elts.map(_.asInstanceOf[Ast.expr.IntNum].n.toInt)
      val cn = s"${bs}_Expected"
      o.bodyConsts += (if (bytes.isEmpty) s"$cn : constant ${KT}Bytes (1 .. 0) := (others => 0);"
                       else s"$cn : constant ${KT}Bytes := ${bytesLiteral(bytes)};")
      o.parse ++= wrapCond(a, None, List(s"${KS}Read_Contents (Buffer, S, $cn);"), rc)
      return
    }
    a.valid.foreach { v =>
      val sliceInts = a.cond.repeat != NoRepeat && (AdaTranslator.fixedElement(a.dataType).isDefined && (a.dataType match {
        case _: FloatMultiType | _: BitsType | _: BitsType1 | EnumType(_, _, _: BitsType) => false
        case _ => true
      }))
      // elements that are read one by one are checked as each is read
      val perElement = a.dataType match {
        case _: BytesType | _: StrType | _: BitsType | _: BitsType1 | EnumType(_, _, _: BitsType) => !AdaTranslator.hasProcess(a.dataType)
        case _ => false
      }
      if (a.cond.repeat != NoRepeat && !sliceInts && !perElement)
        throw new AdaUnsupported("`valid` on a repeated field that is not a repetition of integers of a fixed size, bytes, strings or bit fields")
    }
    if (a.cond.repeat != NoRepeat && AdaTranslator.hasProcess(a.dataType)) throw new AdaUnsupported("`process` on a repeated field")
    a.cond.repeat match {
      case NoRepeat =>
        a.dataType match {
          case st: SwitchType => genSwitch(cs, a, st, o, rc)
          case dt => genScalar(cs, a, dt, firstAlign, o, rc)
        }
      case rep =>
        genRepeat(cs, a, rep, o, rc)
    }
  }

  // -------------------------------------------------------------- processing

  /**
    * A field with `process`: the bytes of the input are kept, and the accessor `X` undoes the processing into
    * an array of the caller; for a field of a type it parses the value from there.
    */
  private def genProcessed(cs: ClassSpec, a: AttrSpec, dt: DataType, o: Out, rc: RC): Unit = {
    val nm = plain(idRaw(a.id))
    val bs = base(idRaw(a.id))
    val (proc, bytesT, userT): (ProcessExpr, BytesType, Option[UserType]) = dt match {
      case b: BytesType => (b.process.get, b, None)
      case ut: UserTypeFromBytes => (ut.process.get, ut.bytes, Some(ut))
      case _ => unsupported("`process` on a string")
    }
    if (a.valid.isDefined) unsupported("`valid` on a field with `process`")
    val (pre, hasName) = condParts(cs, a, o)
    val raw = s"This.$nm"
    o.comps += s"$nm : ${KT}Slice;"
    o.belongs += s"${KT}Within ($raw, Buffer)"
    opTypes += "Length"
    val k = idRaw(a.id)
    val there = if (hasName.isEmpty) Nil else List(s"Requires that it is there ($hasName)")
    val procName = proc match {
      case ProcessXor(_) => "xor"
      case ProcessRotate(true, _) => "rol"
      case ProcessRotate(false, _) => "ror"
      case ProcessCustom(name, _) => name.mkString(".")
      case _ => "zlib"
    }
    o.unread += nm
    val rawIs = userT.map(u => s"the bytes of ${whatIs(u)}").getOrElse("bytes")
    accessor(o, s"${bs}_Raw", KT + "Slice", pre, None, raw,
      comment = describe(List(s"Field ${q(k)}, $rawIs as they are in the input, before the processing (`process: $procName`) is undone, " +
        s"as the slice of the buffer that holds them${coverText(bytesT)}"), DocSpec.EMPTY, List(s"$nm undoes the processing") ++ there))
    o.parse ++= wrapCond(a, if (hasName.isEmpty) None else Some(hasName), readBytes(bytesT, raw, rc, defaultTarget = false), rc)

    // the procedure
    val sc = new Scope
    val rcP = RC("Sub", if (storesOrder(cs)) "This.Order" else "", sc, a.path)
    val rcKey = RC("Unavailable_Stream", if (storesOrder(cs)) "This.Order" else "", sc, a.path)
    val src = s"Buffer ($raw.First .. $raw.Last)"
    val isZlib = proc == ProcessZlib
    val isCustom = proc.isInstanceOf[ProcessCustom]
    val procNames = proc match { case ProcessCustom(name, _) => name; case _ => Nil }
    val zlibKinds = "Kaitai.Zlib."
    // The call of Decode of the package that the description names: the bytes, the arguments of the description, and
    // the array, `Last` and `Outcome`; the conditions under which the arguments are defined
    def customCall(dst: String, last: String): (List[String], List[String]) = proc match {
      case ProcessCustom(name, args) =>
        val pkg = processPackage(name)
        val ts = args.toList.zipWithIndex.map { case (e, i) =>
          val t = T(e, rcKey, "Arg", unique = true)
          val code = t.vt match {
            case VInt | VBool => t.code
            case VBytes => s"Buffer (${t.atom}.First .. ${t.atom}.Last)"
            case VBytesLit(_) => t.code
            case other => unsupported(s"argument ${i + 1} of the custom `process: ${name.mkString(".")}`, which is ${kindOf(other)}; only integers, booleans and bytes can be passed")
          }
          (code, t.guards)
        }
        (List(s"$pkg.Decode (${(List(src) ++ ts.map(_._1) ++ List(dst, last, "Outcome")).mkString(", ")});"), ts.flatMap(_._2))
      case _ => (Nil, Nil)
    }
    // the call of the processing from src into dst, and the conditions under which it is defined
    def processCall(dst: String): (List[String], List[String]) = proc match {
      case ProcessXor(key) =>
        val t = T(key, rcKey, "Key", unique = true)
        t.vt match {
          case VInt | VEnum(_) =>
            val (code, extra) = convertArg(t, KT + "U8", ParamDefSpec(a.path, NamedIdentifier("key"), Int1Type(false)))
            (List(s"Kaitai.Processing.Xor_One ($src, $code, $dst);"), t.guards ++ extra)
          case VBytes =>
            (List(s"Kaitai.Processing.Xor_Many ($src, Buffer (${t.atom}.First .. ${t.atom}.Last), $dst);"),
             t.guards ++ List(s"not ${KT}Is_Empty (${t.code})"))
          case VBytesLit(bs0) =>
            if (bs0.isEmpty) unsupported("`xor` with an empty key")
            (List(s"Kaitai.Processing.Xor_Many ($src, ${t.code}, $dst);"), t.guards)
          case other => unsupported(s"`xor` with a key of $other")
        }
      case ProcessRotate(left, amount) =>
        val t = T(amount, rcKey, "Amount", unique = true)
        t.vt match {
          case VInt | VEnum(_) =>
            if (t.isLiteral) {
              val n = (((t.lo % 8) + 8) % 8).toInt
              val k = if (left) n else (8 - n) % 8
              (List(s"Kaitai.Processing.Rotate_Left ($src, $k, $dst);"), Nil)
            } else {
              val m = s"Kaitai.Arithmetic.Modulo (${t.code}, 8)"
              val k = if (left) s"Integer ($m)" else s"Integer (8 - $m)"
              (List(s"Kaitai.Processing.Rotate_Left ($src, $k, $dst);"), t.guards)
            }
          case other => unsupported(s"`rol`/`ror` with an amount of $other")
        }
      case _ => unsupported("`process`")
    }
    val keyGuards: List[String] =
      if (isZlib) Nil else if (isCustom) customCall("Target", "Last")._2 else processCall("Target")._2
    val outcomeOfZlib = List(
      "case Inflated is",
      s"   when ${zlibKinds}Done =>",
      "      Outcome := Kaitai.Types.Success;",
      s"   when ${zlibKinds}Corrupt =>",
      "      Outcome := Kaitai.Types.Illegal_Sequence;",
      s"   when ${zlibKinds}Target_Full =>",
      "      Outcome := Kaitai.Types.Capacity_Exceeded;",
      "end case;"
    )
    userT match {
      case None =>
        val dst = "Target (Target'First .. Last)"
        val params = s"This : T; Buffer : ${KT}Bytes; Target : in out ${KT}Bytes; Last : out ${KT}Length; Outcome : out ${KT}Status_Kind"
        val post =
          if (isZlib || isCustom)
            s"Last >= Target'First - 1 and then Last - (Target'First - 1) <= ${KT}Length (Target'Length) and then (if Outcome /= ${KT}Success then Last = Target'First - 1)"
          else s"(if Outcome = ${KT}Success then Last = Target'First + ${KT}Size (${bs}_Raw (This)) - 1 else Last = Target'First - 1)"
        opTypes += "Status_Kind"
        val notUsable = if (isZlib) "Illegal_Sequence if the data are not valid zlib data"
                        else if (isCustom) "Arithmetic_Error if an argument of the process is not defined"
                        else if (procName == "xor") "Arithmetic_Error if the key is not defined or not usable (an integer outside 0 .. 255, or no bytes)"
                        else "Arithmetic_Error if the expression of the amount is not defined"
        o.pub ++= ind(describe(List(s"Field ${q(k)}, the bytes of ${bs}_Raw with the processing (`process: $procName`) undone, written to Target (Target'First .. Last)"),
          a.doc, List(s"Parse does not do this: the procedure does it at every call, and This does not keep the result") ++ there) ++
          tag("param", "This", "The value that has the field") ++
          tag("param", "Buffer", "The buffer that This was parsed from, unchanged") ++
          tag("param", "Target", "Where the result goes, from Target'First, which must be at least 1. It must have room for " +
            (if (isZlib) "the inflated bytes" else if (isCustom) s"the bytes that Decode of ${processPackage(procNames)} delivers" else s"as many bytes as ${bs}_Raw has")) ++
          tag("param", "Last", "The index in Target of the last byte of the result: Target'First - 1 if the result is empty or Outcome is not Success") ++
          tag("param", "Outcome", (List("Success", "Capacity_Exceeded if Target is too small") ++
            (if (isZlib || keyGuards.nonEmpty) List(notUsable) else Nil) ++
            (if (isCustom) List(s"or else why Decode of ${processPackage(procNames)} did not accept the bytes") else Nil)).mkString(", ")) ++ List(
          s"procedure $nm ($params)", "with",
          s"  Pre  => $pre and then Belongs_To (This, Buffer) and then Target'First >= 1,",
          s"  Post => $post;", ""))
        val stmts: List[String] =
          if (isZlib)
            List(s"${zlibKinds}Inflate ($src, Target, Last, Inflated);") ++ outcomeOfZlib
          else if (isCustom) {
            val (call, gs) = customCall("Target", "Last")
            if (gs.isEmpty) call
            else List(s"if ${conjoin(gs)} then") ++ ind(call) ++
              List("else", "   Last := Target'First - 1;", s"   Outcome := ${KT}Arithmetic_Error;", "end if;")
          } else {
            val (call, gs) = processCall(dst)
            val work =
              if (gs.isEmpty) call ++ List(s"Outcome := ${KT}Success;")
              else List(s"if ${conjoin(gs)} then") ++ ind(call ++ List(s"Outcome := ${KT}Success;")) ++
                List("else", s"   Last := Target'First - 1;", s"   Outcome := ${KT}Arithmetic_Error;", "end if;")
            List(
              s"if ${KT}Size ($raw) > Target'Length then",
              "   Last := Target'First - 1;",
              s"   Outcome := ${KT}Capacity_Exceeded;",
              s"elsif ${KT}Is_Empty ($raw) then",
              "   Last := Target'First - 1;",
              s"   Outcome := ${KT}Success;",
              "else",
              s"   Last := Target'First + (${KT}Size ($raw) - 1);") ++ ind(work) ++ List("end if;")
          }
        val decls = (if (isZlib) List(s"Inflated : ${zlibKinds}Result_Kind;") else Nil) ++ sc.decls.toList
        val unref = if (stmts.exists(_.contains("Buffer"))) Nil else List("pragma Warnings (Off, Buffer);")
        o.bodyAfter ++= List(s"procedure $nm ($params) is") ++ ind(decls ++ unref) ++ List("begin") ++ ind(stmts) ++ List(s"end $nm;", "")
      case Some(ut) =>
        val pkg = qualOf(ut.classSpec.get)
        val belongsOk = hasBelongs(ut.classSpec.get)
        val params = s"This : T; Buffer : ${KT}Bytes; Storage : in out ${KT}Bytes; Result : out ${userPkg(ut)}.T; Outcome : out ${KT}Status_Kind"
        opTypes += "Status_Kind"
        val notUsable = if (isZlib) "Illegal_Sequence if the data are not valid zlib data"
                        else if (isCustom) "Arithmetic_Error if an argument of the process is not defined"
                        else if (procName == "xor") "Arithmetic_Error if the key is not defined or not usable (an integer outside 0 .. 255, or no bytes)"
                        else "Arithmetic_Error if the expression of the amount is not defined"
        o.pub ++= ind(describe(List(s"Field ${q(k)}, ${whatIs(ut)}: the bytes of ${bs}_Raw with the processing (`process: $procName`) undone into Storage, and the value parsed from there"),
          a.doc, List(s"Parse does not do this: the procedure does it at every call, and This does not keep the result") ++ there) ++
          tag("param", "This", "The value that has the field") ++
          tag("param", "Buffer", "The buffer that This was parsed from, unchanged") ++
          tag("param", "Storage", "Where the processed bytes go, from Storage'First, which must be at least 1. It must have room for " +
            (if (isZlib) "the inflated bytes" else if (isCustom) s"the bytes that Decode of ${processPackage(procNames)} delivers" else s"as many bytes as ${bs}_Raw has")) ++
          tag("param", "Result", "The value. Valid if and only if Outcome is Success" +
            (if (belongsOk) ". It refers to Storage, not to Buffer, so Storage must stay unchanged while Result is used" else "")) ++
          tag("param", "Outcome", "Success, Capacity_Exceeded if Storage is too small, " +
            (if (isZlib) "Illegal_Sequence if the data are not valid zlib data, " else if (keyGuards.nonEmpty) notUsable + ", " else "") +
            (if (isCustom) s"why Decode of ${processPackage(procNames)} did not accept the bytes, or else why" else "or else why") +
            " the value was not accepted") ++ List(
          s"procedure $nm ($params)", "with",
          s"  Pre  => $pre and then Belongs_To (This, Buffer) and then Storage'First >= 1,",
          s"  Post => $pkg" + s"Valid (Result) = (Outcome = ${KT}Success)" + (if (belongsOk) s" and then ${pkg}Belongs_To (Result, Storage);" else ";"), ""))
        val dst = "Storage (Storage'First .. Last)"
        val (pcs, args) = callArgs(ut, rcP)
        val parseStmts = List(s"Sub := ${KS}Open (Storage (Storage'First .. Last));") ++ pcs ++
          List(s"${pkg}Parse (${(List("Result", "Storage", "Sub") ++ args).mkString(", ")});", s"Outcome := ${KS}Status (Sub);")
        val stmts: List[String] =
          if (isZlib)
            List(s"${zlibKinds}Inflate ($src, Storage, Last, Inflated);", "case Inflated is", s"   when ${zlibKinds}Done =>") ++ ind(parseStmts, 2) ++
              List(s"   when ${zlibKinds}Corrupt =>", "      Result := None;", s"      Outcome := ${KT}Illegal_Sequence;",
                s"   when ${zlibKinds}Target_Full =>", "      Result := None;", s"      Outcome := ${KT}Capacity_Exceeded;", "end case;")
          else if (isCustom) {
            val (call, gs) = customCall("Storage", "Last")
            val work = call ++ List(s"if Outcome = ${KT}Success then") ++ ind(parseStmts) ++ List("else", "   Result := None;", "end if;")
            if (gs.isEmpty) work
            else List(s"if ${conjoin(gs)} then") ++ ind(work) ++ List("else", "   Result := None;", s"   Outcome := ${KT}Arithmetic_Error;", "end if;")
          } else {
            val (call, gs) = processCall(dst)
            val work = List(s"if not ${KT}Is_Empty ($raw) then") ++ ind(call) ++ List("end if;") ++ parseStmts
            val guardedWork =
              if (gs.isEmpty) work
              else List(s"if ${conjoin(gs)} then") ++ ind(work) ++ List("else", "   Result := None;", s"   Outcome := ${KT}Arithmetic_Error;", "end if;")
            List(s"if ${KT}Size ($raw) > Storage'Length then", "   Result := None;", s"   Outcome := ${KT}Capacity_Exceeded;", "else",
              s"   Last := Storage'First + ${KT}Size ($raw) - 1;") ++ ind(guardedWork) ++ List("end if;")
          }
        val decls = List(s"Last : ${KT}Length;", s"Sub : ${KS}Stream;", s"None : ${userPkg(ut)}.T;") ++
          (if (isZlib) List(s"Inflated : ${zlibKinds}Result_Kind;") else Nil) ++ sc.decls.toList
        o.bodyAfter ++= List(s"procedure $nm ($params) is") ++ ind(decls) ++ List("begin") ++ ind(stmts) ++ List(s"end $nm;", "")
    }
    if (o.bodyAfter.exists(_.contains("Unavailable_Stream"))) unsupported("`_io` in an argument of a processed field")
  }

  /** A field of the type of the record itself: not kept, parsed again when asked for. */
  private def genSelfField(cs: ClassSpec, a: AttrSpec, ut: UserType, o: Out, rc: RC): Unit = {
    val nm = plain(idRaw(a.id))
    val bs = base(idRaw(a.id))
    val (pre, hasName) = condParts(cs, a, o)
    if (a.valid.isDefined) unsupported("`valid` on a field of its own type")
    opTypes += "Status_Kind"
    o.comps += s"${bs}_Io : ${KS}Stream;"
    o.belongs += s"${KS}Is_Valid (This.${bs}_Io, Buffer)"
    val k = idRaw(a.id)
    val there = if (hasName.isEmpty) Nil else List(s"Requires that it is there ($hasName)")
    o.rereads += nm
    o.pub ++= ind(describe(List(s"Field ${q(k)}, ${whatIs(ut)} (the type itself)"), a.doc,
      List("It is not kept in This: Parse has gone over it once, and this procedure parses it again at every call") ++ there) ++
      tag("param", "This", "The value that has the field") ++
      tag("param", "Buffer", "The buffer that This was parsed from, unchanged") ++
      tag("param", "Result", "The field. Valid if and only if Outcome is Success") ++
      tag("param", "Outcome", "Success, or why the value was not accepted") ++ List(
      s"procedure $nm (This : T; Buffer : ${KT}Bytes; Result : out T; Outcome : out ${KT}Status_Kind)",
      "with",
      s"  Pre  => $pre and then Belongs_To (This, Buffer),",
      s"  Post => Valid (Result) = (Outcome = ${KT}Success) and then Belongs_To (Result, Buffer);", ""))
    val helper = s"Parse_${bs}_Element"
    val elScope = new Scope
    val inHelperRc = RC("S", if (storesOrder(cs)) "This.Order" else "", elScope, a.path)
    val elemStmts = readValue(ut, "Element", inHelperRc, defaultTarget = true)
    val helperSpec = s"procedure $helper (Buffer : ${KT}Bytes; S : in out ${KS}Stream; This : T; Element : out T)"
    o.bodyBefore ++= List(s"--  Parse the field $nm", helperSpec, "with", s"  Pre  => ${KS}Is_Valid (S, Buffer),",
      s"  Post => ${KS}Is_Valid (S, Buffer) and then ${KS}Advanced (S'Old, S) and then Valid (Element) = ${KS}OK (S) and then Belongs_To (Element, Buffer),",
      "  Subprogram_Variant => (Decreases => This.Depth, Decreases => 0);", "")
    o.bodyBefore ++= List(s"$helperSpec is") ++ ind(elScope.decls.toList) ++ List("begin") ++ ind(elemStmts) ++ List(s"end $helper;", "")
    o.bodyAfter ++= List(
      s"procedure $nm (This : T; Buffer : ${KT}Bytes; Result : out T; Outcome : out ${KT}Status_Kind) is",
      s"   L : ${KS}Stream := This.${bs}_Io;",
      "begin",
      s"   $helper (Buffer, L, This, Result);",
      s"   Outcome := ${KS}Status (L);",
      s"end $nm;", "")
    val el = rc.scope.fresh("Element")
    rc.scope.decls += s"$el : T;"
    rc.scope.passesThis = true
    o.parse ++= wrapCond(a, if (hasName.isEmpty) None else Some(hasName),
      List(s"This.${bs}_Io := S;", s"$helper (Buffer, S, This, $el);", s"if not Valid ($el) then", "   " + failStmt(rc, "Limit_Exceeded"), "end if;"), rc)
  }

  private def genScalar(cs: ClassSpec, a: AttrSpec, dt: DataType, firstAlign: List[String], o: Out, rc: RC): Unit = {
    dt match {
      case ut: UserType if ut.classSpec.get eq cs => return genSelfField(cs, a, ut, o, rc)
      case _ =>
    }
    if (AdaTranslator.hasProcess(dt)) return genProcessed(cs, a, dt, o, rc)
    val nm = plain(idRaw(a.id))
    val bs = base(idRaw(a.id))
    val (stored, default) = storedType(dt, a.path)
    val (pre, hasName) = condParts(cs, a, o)
    val k = idRaw(a.id)
    val there = if (hasName.isEmpty) Nil else List(s"Requires that it is there ($hasName)")
    o.comps += s"$nm : $stored${default.map(d => s" := $d").getOrElse("")};"
    val target = s"This.$nm"
    dt match {
      case et: EnumType =>
        enumAccessors(o, nm, bs, stored, et, pre, s"Field ${q(k)}", "as the integer that is in the data", "The integer in the data", a.doc, there)
      case FloatMultiType(w, _) =>
        val fl = if (w.width == 4) "Kaitai.Floats.F32" else "Kaitai.Floats.F64"
        accessor(o, s"${bs}_Bits", stored, pre, None, s"This.$nm",
          comment = describe(List(s"Field ${q(k)}, ${whatIs(dt)}, as the unsigned integer of its bits that is in the data"), DocSpec.EMPTY, there))
        accessor(o, nm, fl, s"$pre and then Kaitai.Floats.Is_Finite (${bs}_Bits (This))", None,
          s"Kaitai.Floats.To_${if (w.width == 4) "F32" else "F64"} (This.$nm)",
          comment = describe(List(s"Field ${q(k)} as a float"), a.doc,
            List(s"Requires that it is neither infinity nor not-a-number: Kaitai.Floats.Is_Finite (${bs}_Bits (This))") ++ there))
      case ut: UserType =>
        val pkg = userPkg(ut)
        val opaque = if (ut.classSpec.get.meta.isOpaque)
          List(s"The description does not define this type; $pkg.Parse reads it, and the package $pkg is written by hand") else Nil
        accessor(o, nm, stored, pre, Some(s"$pkg.Valid ($nm'Result)"), s"This.$nm",
          comment = describe(List(s"Field ${q(k)}, ${whatIs(dt)}"), a.doc, opaque ++ there))
        o.valid += validWrap(a, s"$pkg.Valid (This.$nm)")
        if (hasBelongs(ut.classSpec.get)) o.belongs += s"$pkg.Belongs_To (This.$nm, Buffer)"
      case _: BytesType | _: StrType =>
        accessor(o, nm, stored, pre, None, s"This.$nm", comment = describe(sliceHead(s"Field ${q(k)}", dt), a.doc, there))
        o.belongs += s"${KT}Within (This.$nm, Buffer)"
      case _ =>
        accessor(o, nm, stored, pre, None, s"This.$nm", comment = describe(List(s"Field ${q(k)}, ${whatIs(dt)}"), a.doc, there))
    }
    val reads = readValue(dt, target, rc) ++ a.valid.toList.flatMap(v => validate(v, dt, target, rc))
    o.parse ++= firstAlign
    o.parse ++= wrapCond(a, if (hasName.isEmpty) None else Some(hasName), reads, rc)
  }

  // ---------------------------------------------------------------- switches

  /** What a key of a case of a switch is, if it is a plain literal or the label of an enumeration */
  private def caseKey(e: Ast.expr): Option[String] = e match {
    case k if k == SwitchType.ELSE_CONST => Some(q("_"))
    case Ast.expr.IntNum(n) => Some(n.toString)
    case Ast.expr.UnaryOp(Ast.unaryop.Minus, Ast.expr.IntNum(n)) => Some((-n).toString)
    case Ast.expr.Bool(v) => Some(v.toString)
    case Ast.expr.Str(t) => Some("\"" + sanitize(t) + "\"")
    case Ast.expr.EnumByLabel(en, lb, _) => Some(q(s"${en.name}::${lb.name}"))
    case _ => None
  }

  private def orderText(e: Option[FixedEndian]): String = e match {
    case Some(LittleEndian) => ", little endian"
    case Some(BigEndian) => ", big endian"
    case _ => ", in the byte order that is decided when the data are parsed"
  }

  /** What a value of the type is, in a few words: "an unsigned integer of 2 bytes, little endian" */
  private def whatIs(dt: DataType): String = dt match {
    case Int1Type(sg) => s"${if (sg) "a signed" else "an unsigned"} integer of 1 byte"
    case IntMultiType(sg, w, e) => s"${if (sg) "a signed" else "an unsigned"} integer of ${w.width} bytes${orderText(e)}"
    case FloatMultiType(w, e) => s"a float of ${w.width} bytes${orderText(e)}"
    case _: BitsType1 => "a single bit"
    case BitsType(w, _) => s"a bit field of $w bits"
    case EnumType(_, _, b) => whatIs(b)
    case _: BooleanType => "a boolean"
    case StrFromBytesType(_, enc, _) => s"a string in $enc"
    case _: StrType => "a string"
    case _: BytesType => "bytes"
    case ut: UserType =>
      val c = ut.classSpec.get
      val n = if (classFile(c) == classFile(topClass)) c.name.last else c.nameAsStr
      s"${if ("aeiouAEIOU".contains(n.head)) "an" else "a"} ${q(n)}"
    case _ => "a value"
  }

  /** What the slice that holds a byte array covers: the bytes that `Parse` found, as the description cuts them */
  private def coverText(bt: BytesType): String = {
    def padPart(term: Option[Seq[Byte]], pad: Option[Int]): List[String] =
      pad.filter(p => term.forall(t => p != unsignedByte(t.last))).toList.map(_ => "without the padding at its end")
    def termPart(term: Option[Seq[Byte]], include: Boolean): List[String] =
      term.toList.map(_ => if (include) "cut after the first terminator, which it includes" else "cut before the first terminator")
    val parts: List[String] = bt match {
      case BytesLimitType(_, term, include, pad, _) => padPart(term, pad) ++ termPart(term, include)
      case BytesEosType(term, include, pad, _) => "taken to the end of the stream" :: (padPart(term, pad) ++ termPart(term, include))
      case BytesTerminatedType(_, include, consume, eos, _) =>
        List(s"up to the first terminator, which it ${if (include) "includes" else "does not include"}; the terminator is " +
          (if (consume) "consumed" else "left in the stream") +
          (if (eos) "; Parse fails if there is none" else "; without one it ends at the end of the stream"))
      case _ => Nil
    }
    if (parts.isEmpty) "" else parts.mkString(", ", ", ", "")
  }

  /** The phrases about a field of bytes or a string, which is a slice of the buffer */
  private def sliceHead(subject: String, dt: DataType): List[String] = dt match {
    case StrFromBytesType(bt, enc, _) =>
      val checked = scala.util.Try(encodingName(enc, Nil)).toOption.exists(_ != "Kaitai.Strings.Single_Byte")
      List(s"$subject, a string in $enc, as the slice of the buffer that holds it${coverText(bt)}") ++
        (if (checked) List("Parse has checked that it is valid in that encoding") else Nil)
    case bt: BytesType => List(s"$subject, bytes, as the slice of the buffer that holds them${coverText(bt)}")
    case _ => List(subject)
  }

  private def isIntCase(dt: DataType): Boolean = dt match {
    case _: IntType | _: EnumType => true
    case _ => false
  }

  private def genSwitch(cs: ClassSpec, a: AttrSpec, st: SwitchType, o: Out, rc: RC): Unit = {
    val nm = plain(idRaw(a.id))
    val bs = base(idRaw(a.id))
    val cases = st.cases.toList
    a.valid.foreach { v =>
      if (!cases.forall(c => isIntCase(c._2)))
        unsupported("`valid` on a field whose type depends on a value and has cases that are not integers")
      if (!cases.exists(_._1 == SwitchType.ELSE_CONST))
        unsupported("`valid` on a field whose type depends on a value and has no `_` case: the value does not exist where no case matches")
      if (v.isInstanceOf[ValidationInEnum])
        unsupported("`valid: in-enum` on a field whose type depends on a value")
    }
    if (cases.exists(c => AdaTranslator.hasProcess(c._2))) unsupported("`process` in a field whose type depends on a value")
    if (cases.exists { case (_, ut: UserType) => ut.classSpec.get eq cs; case _ => false })
      unsupported("a field whose type depends on a value and can be the type itself")
    val elseCase = cases.find(_._1 == SwitchType.ELSE_CONST).map(_._2)
    val labeled = cases.filter(_._1 != SwitchType.ELSE_CONST)
    val allInt = cases.forall(c => isIntCase(c._2))
    val onT = T(st.on, rc, "On")
    val (pre, hasName) = condParts(cs, a, o)
    val k = idRaw(a.id)
    val there = if (hasName.isEmpty) Nil else List(s"Requires that it is there ($hasName)")

    // the way the cases are selected
    def labelCode(e: Ast.expr): String = {
      val t = T(e, rc)
      if (!t.isLiteral) throw new AdaUnsupported("case of a switch that is not a literal")
      t.code
    }
    def choose(branches: List[(Option[Ast.expr], List[String])]): List[String] = {
      // branches in order; None is the else branch
      val elseB = branches.find(_._1.isEmpty).map(_._2).filter(_.nonEmpty).getOrElse(List("null;"))
      val others = branches.filter(_._1.isDefined)
      onT.vt match {
        case VInt | VEnum(_) | VBool if !(onT.vt == VBool && false) =>
          val useNative = onT.native.isDefined && onT.guards.isEmpty && onT.vt == VInt &&
            labeled.forall { case (k, _) =>
              val t = T(k, rc)
              val (_, plo, phi) = AdaTranslator.intInfo(Int1Type(false)).get
              val nat = onT.native.get._2
              val range = nat match {
                case "U8" => (BigInt(0), BigInt(255)); case "S8" => (BigInt(-128), BigInt(127))
                case "U16" => (BigInt(0), BigInt(65535)); case "S16" => (BigInt(-32768), BigInt(32767))
                case "U32" => (BigInt(0), (BigInt(1) << 32) - 1); case "S32" => (-(BigInt(1) << 31), (BigInt(1) << 31) - 1)
                case _ => (AdaTranslator.S64Min, AdaTranslator.S64Max)
              }
              t.lo >= range._1 && t.hi <= range._2
            }
          val sel = if (useNative) onT.native.get._1 else onT.code
          val lines = ListBuffer[String]()
          if (others.exists { case (Some(k), _) => labelCode(k).startsWith("-"); case _ => false }) {
            // GNAT is very slow on a case with a negative choice over a 64-bit type
            others.zipWithIndex.foreach { case ((Some(k), stmts), i) =>
              lines += s"${if (i == 0) "if" else "elsif"} $sel = ${labelCode(k)} then"
              lines ++= ind(stmts)
              case _ =>
            }
            lines += "else"
            lines ++= ind(elseB)
            lines += "end if;"
            return guarded(if (useNative) Nil else onT.guards, lines.toList, rc)
          }
          lines += s"case $sel is"
          others.foreach { case (Some(k), stmts) => lines += s"   when ${labelCode(k)} =>"; lines ++= ind(stmts, 2); lines += "" ; case _ => }
          lines += "   when others =>"
          lines ++= ind(elseB, 2)
          lines += "end case;"
          guarded(if (useNative) Nil else onT.guards, lines.toList, rc)
        case VStr(_) | VStrLit(_) | VBytes | VBytesLit(_) =>
          // strings and bytes are compared one case after the other; a switch that has only `_` does not compare
          val lines = ListBuffer[String]()
          others.zipWithIndex.foreach { case ((Some(k), stmts), i) =>
            val c = T(Ast.expr.Compare(st.on, Ast.cmpop.Eq, k), rc)
            lines += s"${if (i == 0) "if" else "elsif"} ${c.code} then"
            lines ++= ind(stmts)
            case _ =>
          }
          if (others.isEmpty) guarded(onT.guards, elseB, rc) else {
            lines += "else"
            lines ++= ind(elseB)
            lines += "end if;"
            guarded(onT.guards, lines.toList, rc)
          }
        case other => throw new AdaUnsupported(s"switch on $other")
      }
    }

    if (allInt) {
      // one component of the widest type
      val adaPlain = switchIntType(st)
      val adaT = KT + adaPlain
      val needHas = elseCase.isEmpty && !hasCond(a)
      val hasN = if (hasCond(a)) hasName else if (needHas) s"${hasNm(bs)}" else ""
      var pre2 = pre
      if (needHas) {
        o.comps += s"${hasNm(bs)} : Boolean := False;"
        o.pub ++= ind(describe(List(s"True if one of the cases of the `switch-on` of the field ${q(k)} applies",
          "The description has no `_` case, so it may be that none applies"), DocSpec.EMPTY) ++
          List(s"function ${hasNm(bs)} (This : T) return Boolean", "with Pre => Valid (This);", ""))
        o.privFuncs += s"function ${hasNm(bs)} (This : T) return Boolean"
        o.privFuncs += s"is (This.${hasNm(bs)});"
        o.privFuncs += ""
        pre2 = s"Valid (This) and then ${hasNm(bs)} (This)"
      }
      o.comps += s"$nm : $adaT := 0;"
      val kinds = cases.map(c => whatIs(c._2)).distinct
      val intIs = if (kinds.size == 1) kinds.head else s"an integer that the cases of its `switch-on` read in different forms, held as $adaT"
      accessor(o, nm, adaT, pre2, None, s"This.$nm",
        comment = describe(List(s"Field ${q(k)}, $intIs"), a.doc,
          if (needHas) List(s"Requires that a case applies (${hasNm(bs)})") else there))
      val branches: List[(Option[Ast.expr], List[String])] =
        labeled.map { case (k, dt) => (Some(k), intBranch(dt, nm, adaT, adaPlain, hasN, rc, a)) } ++
          elseCase.toList.map(dt => (None, intBranch(dt, nm, adaT, adaPlain, hasN, rc, a)))
      if (elseCase.isEmpty) rc.scope.needsInit = true
      // the value is checked as it is held, whichever case read it
      val valueType: DataType = adaPlain match {
        case "U8" => Int1Type(false)
        case "S8" => Int1Type(true)
        case other => IntMultiType(other.head == 'S', other.drop(1).toInt match { case 16 => Width2; case 32 => Width4; case _ => Width8 }, None)
      }
      val checks = a.valid.toList.flatMap(v => validate(v, valueType, s"This.$nm", rc))
      o.parse ++= wrapCond(a, if (hasCond(a)) Some(hasName) else None, choose(branches) ++ checks, rc)
      return
    }

    // variants
    val variants = switchVariants(st)
    def variantOf(dt: DataType): String = variants.find(_._1 == dt).get._2
    val kindT = s"${bs}_Kind"
    val varT = s"${bs}_Variant"
    val none = s"${bs}_Is_None"
    val lits = variants.toList.map { case (_, n) => s"${bs}_Is_$n" } :+ none
    val kindTags = variants.toList.flatMap { case (dt, n) =>
      val keys = st.cases.toList.filter(_._2 == dt).map(c => caseKey(c._1))
      val cased = if (keys.nonEmpty && keys.forall(_.isDefined)) s", ${if (keys.size == 1) "case" else "cases"} ${keys.flatten.mkString(", ")}" else ""
      tag("enum", s"${bs}_Is_$n", s"${whatIs(dt)}$cased")
    } ++ tag("enum", none,
      if (elseCase.isEmpty) "no case applies to the value that is switched on, and nothing is read for the field"
      else if (hasCond(a)) "only if the field is not there, since the `_` case applies where no other does"
      else "never in a valid value, since the `_` case applies where no other does")
    o.pub ++= ind(render(List(P(s"What the field ${q(k)} is in a value"))) ++ kindTags ++ List(s"type $kindT is (${lits.mkString(", ")});", ""))
    accessor(o, s"${bs}_Case", kindT, pre, None, s"This.$nm.Kind", comment = describe(List(s"What the field ${q(k)} is in This"), a.doc, there))
    variants.foreach { case (dt, n) =>
      val (ty, post, extra) = dt match {
        case ut: UserType => (userPkg(ut) + ".T", Some(s"${userPkg(ut)}.Valid (${bs}_As_$n'Result)"), "")
        case _ => (KT + "Slice", None, "")
      }
      val asWhat = dt match {
        case _: UserType => whatIs(dt)
        case _ => s"${whatIs(dt)}, as a slice of the buffer"
      }
      accessor(o, s"${bs}_As_$n", ty, s"$pre and then ${bs}_Case (This) = ${bs}_Is_$n", post, s"This.$nm.$n",
        comment = describe(List(s"The field ${q(k)} as $asWhat"), DocSpec.EMPTY,
          List(s"Requires that ${bs}_Case (This) = ${bs}_Is_$n" + (if (hasName.isEmpty) "" else s" and that it is there ($hasName)"))))
    }
    val rec = ListBuffer[String]()
    rec += s"type $varT (Kind : $kindT := $none) is record"
    rec += "   case Kind is"
    variants.foreach { case (dt, n) =>
      val ty = dt match { case ut: UserType => userPkg(ut) + ".T"; case _ => KT + "Slice" }
      rec += s"      when ${bs}_Is_$n =>"
      rec += s"         $n : $ty;"
      rec += ""
    }
    rec += s"      when $none =>"
    rec += "         null;"
    rec += "   end case;"
    rec += "end record;"
    rec += ""
    o.privTypes ++= rec
    o.comps += s"$nm : $varT;"
    val validCases = variants.toList.collect { case (ut: UserType, n) => s"when ${bs}_Is_$n => ${userPkg(ut)}.Valid (This.$nm.$n)" }
    if (validCases.nonEmpty)
      o.valid += validWrap(a, s"(case This.$nm.Kind is ${(validCases :+ "when others => True").mkString(", ")})")
    val belongCases = variants.toList.collect {
      case (ut: UserType, n) if hasBelongs(ut.classSpec.get) => s"when ${bs}_Is_$n => ${userPkg(ut)}.Belongs_To (This.$nm.$n, Buffer)"
      case (_: BytesType | _: StrType, n) => s"when ${bs}_Is_$n => ${KT}Within (This.$nm.$n, Buffer)"
    }
    if (belongCases.nonEmpty)
      o.belongs += s"(case This.$nm.Kind is ${(belongCases :+ "when others => True").mkString(", ")})"
    val branches: List[(Option[Ast.expr], List[String])] =
      labeled.map { case (k, dt) => (Some(k), variantBranch(dt, nm, bs, variantOf(dt), rc)) } ++
        elseCase.toList.map(dt => (None, variantBranch(dt, nm, bs, variantOf(dt), rc))) ++
        (if (elseCase.isEmpty) List((None, List(s"This.$nm := (Kind => $none);"))) else Nil)
    o.parse ++= wrapCond(a, if (hasCond(a)) Some(hasName) else None, choose(branches), rc)
  }

  /**
    * The name that the variant of a switch gets for a case of the type `c`: its own name, with `_T` after it where the
    * type is a package of its own (the top-level type of another description, an opaque type). The component of the
    * variant would otherwise have the name of that package, which it must not have.
    */
  private def variantBase(c: ClassSpec): String =
    if (c.name.size == 1 && (c.meta.isOpaque || classFile(c) != classFile(topClass))) base(c.name.last) + "_T"
    else base(c.name.last)

  /** The variants of a switch that is not all integers, in order: the type of the case and the name `Is_<Name>` is built from. */
  def switchVariants(st: SwitchType): List[(DataType, String)] = {
    val variants = ListBuffer[(DataType, String)]()
    val usedNames = mutable.Set[String]()
    st.cases.toList.foreach { case (_, dt) =>
      if (!variants.exists(_._1 == dt)) {
        val baseName = dt match {
          case ut: UserType => variantBase(ut.classSpec.get)
          case _: BytesType => "Bytes"
          case _: StrType => "Str"
          case other => throw new AdaUnsupported(s"switch with case of type $other mixed with other types")
        }
        var n = baseName
        var i = 2
        while (usedNames.contains(n) || n == "Kind") { n = s"${baseName}_$i"; i += 1 }
        usedNames += n
        variants += ((dt, n))
      }
    }
    variants.toList
  }

  /** The Ada type, without package, of the component that holds a switch whose cases are all integers: the widest one. */
  def switchIntType(st: SwitchType): String = {
    val infos = st.cases.toList.map(c => AdaTranslator.intInfo(c._2 match { case EnumType(_, _, b) => b; case x => x }).get)
    val signed = infos.exists(_._2 < 0)
    val bitsOf = infos.map(i => i._1.drop(1).toInt)
    val hasU64 = infos.exists(i => i._1 == "U64" && i._3 > AdaTranslator.S64Max)
    val adaPlain =
      if (!signed) s"U${bitsOf.max}"
      else if (infos.forall(_._2 < 0)) s"S${bitsOf.max}"
      else if (infos.filter(_._2 >= 0).forall(i => i._3 < (BigInt(1) << 32))) "S64"
      else throw new AdaUnsupported("switch mixing signed and unsigned integers")
    if (signed && infos.exists(_._2 >= 0) && hasU64) throw new AdaUnsupported("switch mixing signed and unsigned integers")
    adaPlain
  }

  private def intBranch(dt: DataType, nm: String, adaT: String, adaPlain: String, hasName: String, rc: RC, a: AttrSpec): List[String] = {
    val own = intAda(dt)
    val setHas = if (hasName.isEmpty || hasCond(a)) Nil else List(s"This.$hasName := True;")
    if (own == adaT) readValue(dt, s"This.$nm", rc) ++ setHas
    else {
      val v = rc.scope.fresh("Value")
      List("declare", s"   $v : $own;", "begin") ++ ind(readValue(dt, v, rc) ++ List(s"This.$nm := $adaT ($v);") ++ setHas) ++ List("end;")
    }
  }

  private def variantBranch(dt: DataType, nm: String, bs: String, vn: String, rc: RC): List[String] = {
    val ty = dt match { case ut: UserType => userPkg(ut) + ".T"; case _ => KT + "Slice" }
    val v = "Value"
    val reads = readValue(dt, v, rc, defaultTarget = true)
    List("declare", s"   $v : $ty;", "begin") ++ ind(reads ++ List(s"This.$nm := (Kind => ${bs}_Is_$vn, $vn => $v);")) ++ List("end;")
  }

  // ------------------------------------------------------------------ repeats

  /** The repeated field of `cs` that `e` names, directly or through a value instance that is just that name */
  private def repeatedOf(cs: ClassSpec, e: Ast.expr, depth: Int = 0): Option[AttrSpec] = e match {
    case Ast.expr.Name(Ast.identifier(n)) if !n.startsWith("_") =>
      memberOpt(cs, n) match {
        case Some(a: AttrSpec) if a.cond.repeat != NoRepeat => Some(a)
        case Some(v: ValueInstanceSpec) if depth < 8 && v.ifExpr.isEmpty => repeatedOf(cs, v.value, depth + 1)
        case _ => None
      }
    case _ => None
  }

  private val keptElemMemo = mutable.Map[String, Map[String, List[Int]]]()

  /**
    * The elements of the repetitions of `cs` whose elements are parsed one by one that an expression needs, by the
    * name of the field: -1 is the last (`x.last`), 0 the first (`x.first`, `x[0]`), k the one with the number k (`x[k]`).
    */
  private def keptElems(cs: ClassSpec): Map[String, List[Int]] = keptElemMemo.getOrElseUpdate(cs.nameAsStr, {
    val acc = mutable.Map[String, Set[Int]]()
    def note(a: AttrSpec, key: Int): Unit =
      if (AdaTranslator.fixedElement(a.dataType).isEmpty) {
        val b = base(idRaw(a.id))
        acc(b) = acc.getOrElse(b, Set()) + key
      }
    def walk(e: Ast.expr): Unit = {
      e match {
        case Ast.expr.Attribute(r, Ast.identifier("first")) => repeatedOf(cs, r).foreach(note(_, 0))
        case Ast.expr.Attribute(r, Ast.identifier("last")) => repeatedOf(cs, r).foreach(note(_, -1))
        case Ast.expr.Subscript(r, Ast.expr.IntNum(k)) if k >= 0 && k < (BigInt(1) << 20) => repeatedOf(cs, r).foreach(note(_, k.toInt))
        case _ =>
      }
      exprKids(e).foreach(walk)
    }
    outsideExprs(cs).foreach(walk)
    acc.map { case (k, v) => k -> v.toList.sorted }.toMap
  })

  override def keptElement(cs: ClassSpec, a: AttrSpec, key: Int): Option[String] =
    if (!keptElems(cs).getOrElse(base(idRaw(a.id)), Nil).contains(key)) Some("it is not one that the description uses")
    else a.dataType match {
      case ut: UserType if ut.classSpec.exists(c => (c eq cs) || reaches(c, cs)) =>
        Some("its type contains the type that has the repetition, so the record could not hold one")
      case EnumType(_, _, _: BitsType) => Some("the elements are enumerations over bit fields")
      case _ => None
    }

  private def genRepeat(cs: ClassSpec, a: AttrSpec, rep: RepeatSpec, o: Out, rc: RC): Unit = {
    val nm = plain(idRaw(a.id))
    val bs = base(idRaw(a.id))
    // the other targets check an element when the field holds the elements up to it; here the field is whole or empty then
    if (namesField(cs, validExprs(a.valid), a))
      fail(a.path, s"`valid` of the repeated field `${idRaw(a.id)}` that uses the field itself (its size or one of its elements)")
    val dt = a.dataType
    val (pre, hasName) = condParts(cs, a, o)
    val comment = a.doc
    val hasOpt = if (hasName.isEmpty) None else Some(hasName)
    AdaTranslator.fixedElement(dt) match {
      case Some(size) => genRepeatSlice(cs, a, dt, size, rep, pre, hasOpt, comment, o, rc)
      case None =>
        dt match {
          case _: UserType => genRepeatCursor(cs, a, dt, rep, pre, hasOpt, comment, o, rc)
          case _: BytesType | _: StrType => genRepeatCursor(cs, a, dt, rep, pre, hasOpt, comment, o, rc)
          case _: BitsType | _: BitsType1 | EnumType(_, _, _: BitsType) => genRepeatCursor(cs, a, dt, rep, pre, hasOpt, comment, o, rc)
          case other => throw new AdaUnsupported(s"repetition of $other")
        }
    }
  }

  private def genRepeatSlice(cs: ClassSpec, a: AttrSpec, dt: DataType, size: Int, rep: RepeatSpec, pre: String, hasOpt: Option[String], doc: DocSpec, o: Out, rc: RC): Unit = {
    val nm = plain(idRaw(a.id))
    val bs = base(idRaw(a.id))
    val k = idRaw(a.id)
    val there = hasOpt.toList.map(h => s"Requires that it is there ($h)")
    val base0 = dt match { case EnumType(_, _, b) => b; case x => x }
    base0 match {
      case _: BitsType | _: BitsType1 => throw new AdaUnsupported("repetition of bit fields")
      case _ =>
    }
    o.comps += s"$nm : ${KT}Slice;"
    if (!rep.isInstanceOf[RepeatUntil] && size > 1) o.valid += s"${KT}Size (This.$nm) mod $size = 0"
    o.belongs += s"${KT}Within (This.$nm, Buffer)"
    accessor(o, s"${bs}_Count", KT + "Length", pre, None, s"${KT}Size (This.$nm) / $size",
      comment = describe(List(s"Number of elements of the repeated field ${q(k)}"), DocSpec.EMPTY, there))
    opTypes += "Length"
    val full = s"$pre and then ${KT}Within (This.$nm, Buffer)".replace(s"$pre and then ${KT}Within (This.$nm, Buffer)", s"$pre and then Belongs_To (This, Buffer) and then Index < ${bs}_Count (This)")
    val at = s"This.$nm.First + Index * $size"
    val dec = "Kaitai.Decoding."
    def raw(width: Int, fe: Option[FixedEndian]): String = {
      val w = width * 8
      def le = s"${dec}U${w}_LE (Buffer, $at)"
      def be = s"${dec}U${w}_BE (Buffer, $at)"
      if (width == 1) s"${dec}U8_At (Buffer, $at)"
      else fe match {
        case Some(LittleEndian) => le
        case Some(BigEndian) => be
        case _ => { opTypes += "Byte_Order"; s"(if This.Order = ${KT}Little_Endian then $le else $be)" }
      }
    }
    val params = s"This : T; Buffer : ${KT}Bytes; Index : ${KT}Length"
    val elemIs = dt match {
      case et: EnumType => s"${whatIs(base0)}, the number of a label of the enumeration ${q(et.enumSpec.get.name.last)}"
      case _ => whatIs(base0)
    }
    val elemAfter = List("Buffer is the buffer that This was parsed from", s"Requires Index < ${bs}_Count (This)") ++ there
    val elemHead = s"Element Index of the repeated field ${q(k)}, counted from 0"
    base0 match {
      case Int1Type(sg) =>
        accessor(o, nm, intAda(base0), full, None, if (sg) s"${dec}To_S8 (${raw(1, None)})" else raw(1, None), params,
          describe(List(s"$elemHead, $elemIs, decoded from Buffer"), doc, elemAfter))
      case IntMultiType(sg, w, fe) =>
        val r = raw(w.width, fe)
        accessor(o, nm, intAda(base0), full, None, if (sg) s"${dec}To_S${w.width * 8} ($r)" else r, params,
          describe(List(s"$elemHead, $elemIs, decoded from Buffer"), doc, elemAfter))
      case FloatMultiType(w, fe) =>
        val r = raw(w.width, fe)
        val bits = floatBits(w)
        val sfx = if (w.width == 4) "F32" else "F64"
        accessor(o, s"${bs}_Bits", bits, full, None, r, params,
          describe(List(s"$elemHead, $elemIs, as the unsigned integer of its bits, decoded from Buffer"), DocSpec.EMPTY, elemAfter))
        accessor(o, nm, s"Kaitai.Floats.$sfx", s"$full and then Kaitai.Floats.Is_Finite (${bs}_Bits (This, Buffer, Index))", None,
          s"Kaitai.Floats.To_$sfx (${bs}_Bits (This, Buffer, Index))", params,
          describe(List(s"$elemHead, as a float, decoded from Buffer"), doc,
            elemAfter ++ List(s"Requires that it is neither infinity nor not-a-number: Kaitai.Floats.Is_Finite (${bs}_Bits (This, Buffer, Index))")))
      case other => throw new AdaUnsupported(s"repetition of $other")
    }
    val target = s"This.$nm"
    val stmts: List[String] = rep match {
      case RepeatExpr(e) =>
        val t = T(e, rc, "Count")
        guarded(t.guards, List(s"${KS}Read_Elements (S, ${countCode(t)}, $size, $target);"), rc)
      case RepeatEos => List(s"${KS}Read_Elements_Full (S, $size, $target);")
      case RepeatUntil(cond) =>
        val start = rc.scope.fresh("Start")
        val done = rc.scope.fresh("Done")
        opTypes += "Length"
        val value = rc.scope.fresh("Value")
        rc.scope.decls += s"$start : ${KS}Stream;"
        rc.scope.decls += s"$done : Boolean;"
        val (valT, _) = storedType(base0 match { case _: FloatMultiType => base0; case _ => base0 }, a.path)
        rc.scope.decls += s"$value : $valT;"
        tr.buffer = Some("Buffer"); tr.io = Some("S"); tr.thisName = "This"; tr.knownValid = Set()
        tr.iterator = Some((dt, value))
        val ct = try floatStep(cond, guard(a.path)(tr.translate(cond)), rc, "Until", false) finally tr.iterator = None
        val check = guarded(ct.guards, List(s"$done := ${ct.code};"), rc, List(s"$done := True;"), init = false)
        List(s"$start := S;", s"$done := False;", s"for I in 1 .. ${KS}Remaining (S) + 1 loop") ++
          ind(readValue(base0, value, rc) ++ List(s"exit when not ${KS}OK (S);") ++ planLoop ++ a.valid.toList.flatMap(v => validate(v, dt, value, rc)) ++ check ++ List(
            s"exit when $done;",
            s"pragma Loop_Invariant (${KS}Is_Valid (S, Buffer) and then ${KS}Advanced ($start, S) and then not $done${planInvariant});"
          )) ++ List(
          "end loop;",
          s"if ${KS}OK (S) and then not $done then",
          "   " + failStmt(rc, "Limit_Exceeded"),
          "end if;",
          s"$target := ${KS}Between ($start, S);"
        )
    }
    // `valid` of a repetition holds for every element: the elements are decoded again and checked
    val validStmts: List[String] = a.valid match {
      case Some(v) if !rep.isInstanceOf[RepeatUntil] =>
        val value = rc.scope.fresh("Value")
        val (valT, _) = storedType(base0, a.path)
        rc.scope.decls += s"$value : $valT;"
        opTypes += "Length"
        val atJ = s"This.$nm.First + (J - 1) * $size"
        val decoded = base0 match {
          case Int1Type(sg) =>
            val r = s"${dec}U8_At (Buffer, $atJ)"
            if (sg) s"${dec}To_S8 ($r)" else r
          case IntMultiType(sg, w, fe) =>
            val bits = w.width * 8
            val le = s"${dec}U${bits}_LE (Buffer, $atJ)"
            val be = s"${dec}U${bits}_BE (Buffer, $atJ)"
            val r = fe match {
              case Some(LittleEndian) => le
              case Some(BigEndian) => be
              case _ => { opTypes += "Byte_Order"; s"(if This.Order = ${KT}Little_Endian then $le else $be)" }
            }
            if (sg) s"${dec}To_S$bits ($r)" else r
          case other => throw new AdaUnsupported(s"`valid` on a repetition of $other")
        }
        List(s"if ${KS}OK (S) then", s"   for J in 1 .. ${KT}Size ($target) / $size loop", s"      $value := $decoded;") ++
          ind(validate(v, dt, value, rc), 2) ++
          List(s"      pragma Loop_Invariant (${KS}Is_Valid (S, Buffer) and then ${KS}Advanced (S'Loop_Entry, S));", "   end loop;", "end if;")
      case _ => Nil
    }
    o.parse ++= wrapCond(a, hasOpt, stmts ++ validStmts, rc)
  }

  /**
    * The least number of whole bytes that a successful read of a value of the type takes from the stream, as far as
    * the description alone tells: 0 where a value may read nothing.
    */
  /** An element that may read nothing: it is not a bit field, which reads at least a bit, and no field of it reads a byte */
  /**
    * The size of an element is `x[_index]`, where `x` is a repetition of integers of a fixed size of the same type: the
    * element with the number that `x` has no element for fails the stream, so the elements that can be parsed are as
    * many as `x` has, and that is bounded by the data.
    */
  private def sizeFromIndex(cs: ClassSpec, dt: DataType): Boolean = {
    val size: Option[Ast.expr] = dt match {
      case BytesLimitType(size, _, _, _, _) => Some(size)
      case StrFromBytesType(BytesLimitType(size, _, _, _, _), _, _) => Some(size)
      case ut: UserTypeFromBytes => ut.bytes match { case BytesLimitType(size, _, _, _, _) => Some(size); case _ => None }
      case _ => None
    }
    size.exists {
      case Ast.expr.Subscript(Ast.expr.Name(x), Ast.expr.Name(i)) if i.name == io.kaitai.struct.format.Identifier.INDEX =>
        cs.seq.exists(m => m.id.humanReadable == x.name && m.cond.repeat != NoRepeat && m.cond.repeat.isInstanceOf[RepeatExpr] &&
          AdaTranslator.fixedElement(m.dataType).isDefined && !AdaTranslator.hasProcess(m.dataType))
      case _ => false
    }
  }

  private def mayBeEmpty(dt: DataType): Boolean = dt match {
    case _: BitsType | _: BitsType1 | EnumType(_, _, _: BitsType) => false
    case _ => minBytes(dt) == 0
  }

  private def minBytes(dt: DataType, seen: List[ClassSpec] = Nil): Int = dt match {
    case Int1Type(_) => 1
    case IntMultiType(_, w, _) => w.width
    case FloatMultiType(w, _) => w.width
    case EnumType(_, _, b) => minBytes(b, seen)
    case ut: UserTypeInstream =>
      ut.classSpec match {
        case Some(c) if !seen.exists(_ eq c) =>
          c.seq.filter(a => a.cond.ifExpr.isEmpty && a.cond.repeat == NoRepeat)
            .foldLeft(0)((n, a) => (n + minBytes(a.dataType, c :: seen)).min(1 << 20))
        case _ => 0
      }
    case _ => 0
  }

  private def genRepeatCursor(cs: ClassSpec, a: AttrSpec, dt: DataType, rep: RepeatSpec, pre: String, hasOpt: Option[String], doc: DocSpec, o: Out, rc: RC): Unit = {
    val nm = plain(idRaw(a.id))
    val bs = base(idRaw(a.id))
    val k = idRaw(a.id)
    val there = hasOpt.toList.map(h => s"Requires that it is there ($h)")
    val isSlice = !dt.isInstanceOf[UserType]
    // a bit field: the element is an integer or a boolean, and the stream of the cursor carries the bit position
    val isScalar = dt match { case _: BitsType | _: BitsType1 | EnumType(_, _, _: BitsType) => true; case _ => false }
    opTypes += "Length"
    val selfElem = dt match { case ut: UserType => ut.classSpec.get eq cs; case _ => false }
    val (elT, elPkg, elBelongs) = dt match {
      case ut: UserType if selfElem => ("T", "", true)
      case ut: UserType => (userPkg(ut) + ".T", userPkg(ut) + ".", hasBelongs(ut.classSpec.get))
      case _ if isScalar => (bitsElementType(bs, dt), "", false)
      case _ => (KT + "Slice", "", true)
    }
    def valid(x: String) = if (isSlice) s"${KS}OK (S)" else s"${elPkg}Valid ($x)"
    val cur = s"${bs}_Cursor"
    o.comps += s"${bs}_Io : ${KS}Stream;"
    o.comps += s"${bs}_Count : ${KT}Length := 0;"
    o.belongs += s"${KS}Is_Valid (This.${bs}_Io, Buffer)"
    o.rereads += s"$bs (see ${bs}_First)"
    // the elements that expressions use are kept in the record
    val keptKeys = if (keptElems(cs).getOrElse(bs, Nil).forall(k => keptElement(cs, a, k).isEmpty)) keptElems(cs).getOrElse(bs, Nil) else Nil
    def keptComp(key: Int) = key match { case 0 => s"${bs}_First_Element"; case -1 => s"${bs}_Last_Element"; case k => s"${bs}_Element_$k" }
    def keptAbsent(key: Int) = if (key <= 0) s"This.${bs}_Count = 0" else s"This.${bs}_Count <= $key"
    def keptOk(comp: String): List[String] =
      if (isScalar) Nil
      else if (isSlice) List(s"${KT}Within ($comp, Buffer)")
      else s"${elPkg}Valid ($comp)" :: (if (elBelongs) List(s"${elPkg}Belongs_To ($comp, Buffer)") else Nil)
    // the components of the record are all set at the start of Parse, so that those not reached are too
    if (keptKeys.nonEmpty) rc.scope.needsInit = true
    keptKeys.foreach { key =>
      val comp = keptComp(key)
      o.comps += s"$comp : $elT${if (isScalar) " := " + defaultOf(elT) else ""};"
      if (!isScalar && !isSlice) o.valid += s"(${keptAbsent(key)} or else ${elPkg}Valid (This.$comp))"
      if (isSlice && !isScalar) o.belongs += s"${KT}Within (This.$comp, Buffer)"
      else if (!isScalar && elBelongs) o.belongs += s"(${keptAbsent(key)} or else ${elPkg}Belongs_To (This.$comp, Buffer))"
    }
    // by the count (a loop whose count is set in it) or by the turn (a loop whose count is set before it)
    def keptInv(byCount: Boolean): String = (if (byCount && keptKeys.nonEmpty && !isScalar) List(s" and then This.${bs}_Count = I") else Nil).mkString + keptKeys.flatMap { key =>
      val ok = keptOk(s"This.${keptComp(key)}")
      if (ok.isEmpty) Nil
      else {
        // the turn I is at least 1: `I <= 1` is `I = 1`, which the compiler would otherwise say is a comparison that can only be an equality
        val gate = if (byCount) keptAbsent(key) else if (key == 1) "I = 1" else s"I <= $key"
        val plainOk = ok.mkString(" and then ")
        // a slice that was not set is empty and lies in any buffer; what is set in the first turn holds in all
        if (isSlice || (!byCount && key <= 0)) List(" and then " + plainOk) else List(s" and then ($gate or else ($plainOk))")
      }
    }.mkString
    // the statements that read one element, and whether they use `_index`
    val elScope = new Scope
    val inHelperRc = RC("S", if (storesOrder(cs)) "This.Order" else "", elScope, a.path)
    tr.iterator = None
    tr.indexCode = Some("Index"); tr.usedIndex = false; tr.sliceUses.clear()
    val elemStmts0 = try readValue(dt, "Element", inHelperRc, defaultTarget = true) finally tr.indexCode = None
    // the slices of This that the element decodes from: they must lie in the buffer
    val elemSlices = tr.sliceUses.toList.sorted
    tr.sliceUses.clear()
    val usesIndex = tr.usedIndex
    tr.usedIndex = false
    if (usesIndex) indexUsers += a.path.mkString("/")
    o.privTypes ++= List(s"type $cur is record", s"   Io   : ${KS}Stream;", s"   Left : ${KT}Length := 0;") ++
      (if (usesIndex) List(s"   Index : ${KT}Length := 0;") else Nil) ++ List("end record;", "")
    // the elements of an index-dependent repetition cannot all be taken to be the same after an empty one
    rep match {
      case RepeatExpr(Ast.expr.IntNum(_)) =>
      case RepeatExpr(_) if usesIndex && mayBeEmpty(dt) && sizeFromIndex(cs, dt) =>
      case RepeatExpr(_) if usesIndex && mayBeEmpty(dt) =>
        throw new AdaUnsupported("repetition whose count comes from the data, whose elements may read nothing, and whose parse depends on `_index`: the data do not bound the number of elements")
      case _ =>
    }
    val elemValid = if (selfElem) "Valid" else s"${elPkg}Valid"
    val elemTag =
      if (isScalar) "The element. If it could not be read, Has_Element (Position) is False afterwards"
      else if (isSlice) "The element, a slice of Buffer. If it could not be read, Has_Element (Position) is False afterwards"
      else "The element. If it could not be parsed it is not valid, and Has_Element (Position) is False afterwards"
    // an element may read nothing: the count can be far larger than the data
    val emptyElems = rep.isInstanceOf[RepeatExpr] && mayBeEmpty(dt) && !usesIndex
    val nextDoc = render(List(P("Parses the element at Position and moves Position to the next one:"), Gap)) ++
      List(s"Position := ${bs}_First (V);", "while Has_Element (Position) loop", "   Next (V, Buffer, Position, Element);") .map("--     " + _) ++
      (if (isSlice) Nil else List(s"   exit when not $elemValid (Element);").map("--     " + _)) ++
      List("   ...", "end loop;").map("--     " + _) ++
      render(List(Gap, P(
        if (isSlice) "Parse has accepted every element, and an element is read again as long as the buffer has not changed"
        else "Parse has accepted every element, and an element is accepted again as long as the buffer has not changed. That is not proven, so check that Element is valid."))) ++
      (if (emptyElems) render(List(Gap, P(s"An element may read nothing, and the count is the one in the data, so the loop runs as often as ${bs}_Count (This) says, which can be far more often than the data are long."))) else Nil) ++
      tag("param", "This", "The value that has the repetition") ++
      tag("param", "Buffer", "The buffer that This was parsed from, unchanged") ++
      tag("param", "Position", "Where to parse; moved to the next element") ++
      tag("param", "Element", elemTag)
    val getDoc = render(List(P(s"Parses the element with the number Index, counted from 0. The elements before it are parsed on the way, so going through all elements with this procedure takes time that grows with the square of their number; use Next for that." +
      (if (emptyElems) " An element that reads nothing ends the search, as it ends Parse: all that follow are the same, so it is the one that is delivered." else "")))) ++
      tag("param", "This", "The value that has the repetition") ++
      tag("param", "Buffer", "The buffer that This was parsed from, unchanged") ++
      tag("param", "Index", s"The number of the element, less than ${bs}_Count (This)") ++
      tag("param", "Element", if (isScalar) "The element" else if (isSlice) "The element, a slice of Buffer" else "The element. If it could not be parsed it is not valid")
    def one(text: String*): List[String] = render(List(P(sentences(text.toList))))
    o.pub ++= ind(
      describe(List(s"Number of elements of the repeated field ${q(k)}"), doc,
        List(s"The elements are not kept in This: Parse has gone over them once, and ${bs}_First with Next, or Get_$bs, parse them again from the buffer") ++ there) ++
      List(s"function ${bs}_Count (This : T) return ${KT}Length", s"with Pre => $pre;", "") ++
      narrowBits(dt).toList.flatMap(w =>
        one(s"The value of an element of the repeated field ${q(k)}, a bit field of $w bits") ++ List(
        s"subtype ${bs}_Element is ${KT}U64 range 0 .. ${(BigInt(1) << w) - 1};", "")) ++
      one(s"A position in the repeated field ${q(k)}, for going through its elements in order") ++ List(
      s"type $cur is private;", "") ++
      one("True if Position lies within Buffer", "It holds for the buffer of the value that Position was taken from") ++ List(
      s"function Belongs_To (Position : $cur; Buffer : ${KT}Bytes) return Boolean;", "") ++
      describe(List(s"The position of the first element of the repeated field ${q(k)}"), DocSpec.EMPTY, there) ++ List(
      s"function ${bs}_First (This : T) return $cur", s"with Pre => $pre;", "") ++
      one("Number of elements from Position to the end") ++ List(
      s"function Remaining (Position : $cur) return ${KT}Length;", "") ++
      one("True if there is an element at Position") ++ List(
      s"function Has_Element (Position : $cur) return Boolean", "is (Remaining (Position) > 0);", "") ++
      nextDoc ++ List(
      s"procedure Next (This : T; Buffer : ${KT}Bytes; Position : in out $cur; Element : out $elT)",
      "with", "  Pre  => Valid (This) and then Belongs_To (Position, Buffer) and then Has_Element (Position)" +
        (if (elemSlices.nonEmpty) " and then Belongs_To (This, Buffer)," else ","),
      "  Post =>", "    Belongs_To (Position, Buffer) and then Remaining (Position) < Remaining (Position'Old)" +
        (if (elBelongs) s"\n    and then ${if (isSlice) KT + "Within" else elPkg + "Belongs_To"} (Element, Buffer);" else ";"), "",
      ) ++ getDoc ++ List(
      s"procedure Get_$bs (This : T; Buffer : ${KT}Bytes; Index : ${KT}Length; Element : out $elT)",
      s"with Pre => $pre and then Belongs_To (This, Buffer) and then Index < ${bs}_Count (This)" +
        (if (elBelongs) s", Post => ${if (isSlice) KT + "Within" else elPkg + "Belongs_To"} (Element, Buffer);" else ";"), ""
    ))
    o.privFuncs += s"function ${bs}_Count (This : T) return ${KT}Length"
    o.privFuncs += s"is (This.${bs}_Count);"
    o.privFuncs += ""
    o.privFuncs += s"function Belongs_To (Position : $cur; Buffer : ${KT}Bytes) return Boolean"
    o.privFuncs += s"is (${KS}Is_Valid (Position.Io, Buffer));"
    o.privFuncs += ""
    o.privFuncs += s"function ${bs}_First (This : T) return $cur"
    o.privFuncs += s"is (Io => This.${bs}_Io, Left => This.${bs}_Count${if (usesIndex) ", Index => 0" else ""});"
    o.privFuncs += ""
    o.privFuncs += s"function Remaining (Position : $cur) return ${KT}Length"
    o.privFuncs += "is (Position.Left);"
    o.privFuncs += ""

    // reading one element
    val usesThis = elemStmts0.exists(_.contains("This"))
    val elemStmtsText = elemStmts0
    val needsHelper = isSlice || usesIndex || elemStmts0.size != 1 || elScope.decls.nonEmpty
    val helper = s"Parse_${bs}_Element"
    val helperParams = s"Buffer : ${KT}Bytes; S : in out ${KS}Stream; " + (if (usesThis) "This : T; " else "") +
      (if (usesIndex) s"Index : ${KT}Length; " else "") + s"Element : out $elT"
    val callThis = if (usesThis) "This, " else ""
    def callIndex(code: String) = if (usesIndex) s"$code, " else ""
    val postElem = s"${KS}Is_Valid (S, Buffer) and then ${KS}Advanced (S'Old, S)" + (if (isSlice) "" else s" and then (if ${valid("Element")} then ${KS}OK (S))") +
      (if (elBelongs) s" and then ${if (isSlice) KT + "Within" else elPkg + "Belongs_To"} (Element, Buffer)" else "")
    def elemCall(stream: String, index: String): String =
      if (needsHelper) s"$helper (Buffer, $stream, ${callThis}${callIndex(index)}Element);"
      else s"${elemStmts0.head.replace("(Element, Buffer, S", s"(Element, Buffer, $stream")}"
    if (needsHelper) {
      o.bodyBefore ++= List(s"--  Parse one element of $nm", s"procedure $helper ($helperParams)", "with", s"  Pre  => ${KS}Is_Valid (S, Buffer)" + elemSlices.map(x => s" and then ${KT}Within ($x, Buffer)").mkString + ",") ++
        (if (selfElem) List(s"  Post => $postElem,", "  Subprogram_Variant => (Decreases => This.Depth, Decreases => 0);", "") else List(s"  Post => $postElem;", ""))
      val declLines = elScope.decls.toList ++ (if (elScope.bit) List(s"Bit : ${KT}U64;") else Nil)
      val body = elemStmts0
      val unref = if (body.exists(_.contains("Buffer"))) Nil else List("pragma Warnings (Off, Buffer);")
      o.bodyBefore ++= List(s"procedure $helper ($helperParams) is") ++ ind(declLines ++ unref) ++ List("begin") ++ ind(body) ++ List(s"end $helper;", "")
    }
    if (isSlice && elemStmts0.isEmpty) throw new AdaUnsupported("empty element")

    // Next and Get_
    val nextBody = List(
      s"procedure Next (This : T; Buffer : ${KT}Bytes; Position : in out $cur; Element : out $elT) is"
    ) ++ (if (usesThis) Nil else List("   pragma Warnings (Off, This);")) ++ List(
      "begin",
      "   " + elemCall("Position.Io", "Position.Index"),
      s"   Position.Left := (if ${valid("Element").replace("OK (S)", "OK (Position.Io)")} then Position.Left - 1 else 0);") ++
      (if (usesIndex) List(s"   Position.Index := (if Position.Index < ${KT}Length'Last then Position.Index + 1 else Position.Index);") else Nil) ++ List(
      "end Next;", ""
    )
    val within = if (isScalar) "" else if (isSlice) s"${KT}Within (Result, Buffer)" else if (elBelongs) s"${elPkg}Belongs_To (Result, Buffer)" else ""
    val getBody = List(
      s"procedure Get_$bs (This : T; Buffer : ${KT}Bytes; Index : ${KT}Length; Element : out $elT) is",
      s"   Position : $cur := ${bs}_First (This);",
      s"   Result   : $elT${if (isScalar) " := " + defaultOf(elT) else ""};") ++ (if (emptyElems) List(s"   Before   : ${KS}Stream;") else Nil) ++ List(
      "begin",
      s"   for I in 0 .. Index loop",
      s"      pragma Loop_Invariant (Belongs_To (Position, Buffer)${if (within.nonEmpty) " and then " + within else ""});",
      "      exit when not Has_Element (Position);") ++
      (if (emptyElems) List("      Before := Position.Io;") else Nil) ++ List(
      "      Next (This, Buffer, Position, Result);") ++
      (if (emptyElems) List("      --  An element that read nothing: so will all that follow",
        s"      exit when ${KS}Pos (Position.Io) = ${KS}Pos (Before) and then ${KS}Bits_Left (Position.Io) = ${KS}Bits_Left (Before);") else Nil) ++ List(
      "   end loop;",
      "   Element := Result;",
      s"end Get_$bs;", ""
    )
    o.bodyAfter ++= nextBody
    o.bodyAfter ++= getBody

    // Parse
    val el = rc.scope.fresh("Element")
    rc.scope.decls += s"$el : $elT;"
    // the value of a bit field is not looked at by Parse
    if (isScalar) rc.scope.decls += s"pragma Warnings (Off, $el);"
    val parseCall = if (needsHelper) {
      if (usesThis) rc.scope.passesThis = true
      s"$helper (Buffer, S, ${callThis}${callIndex("I - 1")}$el);"
    } else elemStmts0.head.replace("(Element, ", s"($el, ")
    val Iv = "I"
    // `valid` is checked on each element as it is read; a check that fails ends the loop
    val checks = a.valid.toList.flatMap(v => validate(v, dt, el, rc)) match {
      case Nil => Nil
      case cs => cs ++ List(s"exit when not ${KS}OK (S);")
    }
    // at most one element per byte that is left; a bit field takes at least a bit, so at most eight per byte, and the
    // bits that the byte at the position still has make up the 8 that is added. `until` has one more turn than there
    // are elements, the one that finds the end of the data, so for bit fields it is that 8 (at most 8 * Remaining + 7
    // elements and the turn that fails) and not one more: the loop is not allowed to pass Length'Last
    val bound =
      if (isScalar) s"(if ${KS}Remaining (S) < ${KT}Length'Last / 8 - 1 then ${KS}Remaining (S) * 8 + 8 else ${KT}Length'Last)"
      else s"${KS}Remaining (S)"
    val untilBound = if (isScalar) bound else s"$bound + 1"
    // a slice has no validity to look at; the loop uses the element in its invariant
    val sliceInv = if (isSlice && !isScalar) s" and then ${KT}Within ($el, Buffer)" else ""
    // after an element is read: the statements that keep it, and what is then true of the record
    def keptStmts(el: String, idx: String): List[String] = keptKeys.flatMap {
      case -1 => List(s"This.${keptComp(-1)} := $el;")
      case 0 => List(s"if $idx = 1 then", s"   This.${keptComp(0)} := $el;", "end if;")
      case k =>
        // an element that read nothing ends the loop, and the numbers after it are all that element
        val cmp = if (rep.isInstanceOf[RepeatExpr] && mayBeEmpty(dt) && !usesIndex) "<=" else "="
        List(s"if $idx $cmp ${k + 1} then", s"   This.${keptComp(k)} := $el;", "end if;")
    }
    val loop: List[String] = rep match {
      case RepeatExpr(e) =>
        val t = T(e, rc, "Count")
        // The count comes from the data. Elements that take at least a byte each end the loop when the stream does;
        // elements that may read nothing do not, so the loop is left at the first one that reads nothing: all that
        // follow start in the same state and read nothing either.
        val (before, same) =
          if (!mayBeEmpty(dt) || usesIndex) (Nil, Nil)
          else {
            val at = rc.scope.fresh("Before")
            rc.scope.decls += s"$at : ${KS}Stream;"
            (List(s"$at := S;"),
             List("--  An element that read nothing: so will all that follow",
               s"exit when ${KS}Pos (S) = ${KS}Pos ($at) and then ${KS}Bits_Left (S) = ${KS}Bits_Left ($at);"))
          }
        guarded(t.guards, List(s"This.${bs}_Count := ${countCode(t)};"), rc, Nil) ++ List(
          s"for $Iv in 1 .. This.${bs}_Count loop"
        ) ++ ind(before ++ List(parseCall, s"exit when not ${valid(el).replace("OK (S)", "OK (S)")};") ++ keptStmts(el, Iv) ++ checks ++ same ++ List(
          s"pragma Loop_Invariant (${KS}Is_Valid (S, Buffer) and then ${KS}Advanced (S'Loop_Entry, S)$sliceInv${keptInv(false)});")) ++ List("end loop;")
      case RepeatEos =>
        List(s"This.${bs}_Count := 0;", s"for $Iv in 1 .. $bound loop") ++
          ind(List(s"exit when ${KS}Is_EOF (S);", parseCall, s"exit when not ${valid(el)};") ++ keptStmts(el, Iv) ++ checks ++ List(s"This.${bs}_Count := $Iv;",
            s"pragma Loop_Invariant (${KS}Is_Valid (S, Buffer) and then ${KS}Advanced (S'Loop_Entry, S)$sliceInv${keptInv(true)});")) ++ List(
          "end loop;", s"if ${KS}OK (S) and then not ${KS}Is_EOF (S) then", "   " + failStmt(rc, "Limit_Exceeded"), "end if;")
      case RepeatUntil(cond) =>
        val done = rc.scope.fresh("Done")
        rc.scope.decls += s"$done : Boolean;"
        tr.buffer = Some("Buffer"); tr.io = Some("S"); tr.thisName = "This"
        tr.iterator = Some((dt, el))
        tr.knownValid = Set(el)
        tr.indexCode = Some(s"$Iv - 1")
        val ct = try floatStep(cond, guard(a.path)(tr.translate(cond)), rc, "Until", false) finally tr.indexCode = None
        tr.iterator = None
        tr.knownValid = Set()
        val check = guarded(ct.guards, List(s"$done := ${ct.code};"), rc, List(s"$done := True;"), init = false)
        List(s"This.${bs}_Count := 0;", s"$done := False;", s"for $Iv in 1 .. $untilBound loop") ++
          ind(List(parseCall, s"exit when not ${valid(el)};") ++ keptStmts(el, Iv) ++ planLoop ++ checks ++ List(s"This.${bs}_Count := $Iv;") ++ check ++ List(
            s"exit when $done;",
            s"pragma Loop_Invariant (${KS}Is_Valid (S, Buffer) and then ${KS}Advanced (S'Loop_Entry, S)$sliceInv and then not $done${planInvariant}${keptInv(true)});")) ++
          List("end loop;", s"if ${KS}OK (S) and then not $done then", "   " + failStmt(rc, "Limit_Exceeded"), "end if;")
      case NoRepeat => Nil
    }
    o.parse ++= wrapCond(a, hasOpt, List(s"This.${bs}_Io := S;") ++ loop, rc)
  }

  // ---------------------------------------------------------------- instances

  private def genValueInstance(cs: ClassSpec, v: ValueInstanceSpec, o: Out): Unit = {
    val nm = plain(idRaw(v.id))
    val bs = base(idRaw(v.id))
    val rc = RC("S", "", new Scope, v.path)
    val path = v.path
    val saveBuf = tr.buffer
    tr.buffer = Some("Buffer"); tr.io = None; tr.thisName = "This"; tr.iterator = None; tr.knownValid = Set()
    val k = idRaw(v.id)
    val kq = q(k)
    bigLiteral(v).foreach { n =>
      // not an S64, so the value is a U64 that expressions cannot use
      accessor(o, nm, KT + "U64", "Valid (This)", None, n.toString, "This : T",
        describe(List(s"Instance $kq, the constant $n, which is above the largest Kaitai.Types.S64 and so is a Kaitai.Types.U64 that no expression can use"), v.doc))
      tr.buffer = saveBuf
      return
    }
    v.dataType match {
      case _: ArrayType =>
        repeatedOf(cs, v.value) match {
          case Some(r) if v.ifExpr.isEmpty =>
            // the value is the repeated field itself: it has no accessor of its own, the accessors of the field are its own
            o.pub ++= ind(describe(List(s"Instance $kq is the repeated field ${q(idRaw(r.id))}; it has no accessors of its own"), v.doc, Nil), 1)
            o.pub += ""
            tr.buffer = saveBuf
            return
          case _ => throw new AdaUnsupported("value instance that is an array, other than a repeated field under another name")
        }
      case _ =>
    }
    val t = guard(path)(tr.translate(v.value))
    val ct = v.ifExpr.map(c => guard(path)(tr.translate(c)))
    val (hasGuard, usesBuf) = valueInfo(cs, v)
    val isSlice = v.dataType match { case _: BytesType | _: StrType => true; case _ => false }
    val params = if (usesBuf) s"This : T; Buffer : ${KT}Bytes" else "This : T"
    val args = if (usesBuf) "This, Buffer" else "This"
    val pre0 = if (usesBuf) "Valid (This) and then Belongs_To (This, Buffer)" else "Valid (This)"
    if (usesBuf && !hasBelongs(cs)) throw new AdaUnsupported("value instance that needs the buffer in a type without slices")
    var pre = pre0
    val bufferText = if (usesBuf) List("Buffer is the buffer that This was parsed from") else Nil
    val computed = List("Computed from the fields at every call") ++ bufferText ++ (if (hasGuard) List(s"Requires ${hasNm(bs)}") else Nil)
    if (hasGuard) {
      val gs = ct.toList.flatMap(c => c.guards ++ List(if (c.prec >= 3) s"(${c.code})" else c.code)) ++ t.guards
      val hasText =
        if (v.ifExpr.isDefined) List(s"True if the instance $kq has a value", "Its condition (`if`) must be defined and hold, and its expression must be defined")
        else if (gs.exists(g => g.contains("Kaitai.Floats.Is_Finite") || g.contains("Kaitai.Float_Arithmetic.")))
          List(s"True if the instance $kq has a value", "Its expression is not defined if a field that it uses is not there, an operation in it overflows or divides by zero, an index is out of range, or a float that it uses is infinity or not-a-number")
        else List(s"True if the instance $kq has a value", "Its expression is not defined if a field that it uses is not there, an operation in it overflows or divides by zero, or an index is out of range")
      o.pub ++= ind(describe(hasText, DocSpec.EMPTY, bufferText) ++ List(s"function ${hasNm(bs)} ($params) return Boolean", s"with Pre => $pre0;", ""))
      o.privFuncs += s"function ${hasNm(bs)} ($params) return Boolean"
      o.privFuncs += s"is (${if (gs.isEmpty) "True" else gs.distinct.mkString("\n and then ")});"
      o.privFuncs += ""
      pre = s"$pre0 and then ${hasNm(bs)} ($args)"
    }
    v.dataType match {
      case et: EnumType =>
        if (isWide(et.enumSpec.get)) throw new AdaUnsupported("value instance of an enumeration that has a value beyond 63 bits")
        val ada = KT + "S64"
        val spec = et.enumSpec.get
        val tyName = enumTypeName(spec)
        val q = tyName.split('.').dropRight(1).mkString(".") match { case "" => ""; case x => x + "." }
        val enumAfter = bufferText ++ (if (hasGuard) List(s"Requires ${hasNm(bs)}") else Nil)
        accessor(o, s"${bs}_Value", ada, pre, None, t.code, params,
          describe(List(s"Instance $kq as the integer that its expression delivers, a Kaitai.Types.S64"), DocSpec.EMPTY, List("Computed from the fields at every call") ++ enumAfter))
        accessor(o, nm, tyName, s"$pre and then ${q}Is_${enumTy(spec)} (${bs}_Value ($args))", None,
          s"${q}To_${enumTy(spec)} (${bs}_Value ($args))", params,
          labelComment(s"Instance $kq", tyName, q, spec, bs, "The integer", v.doc, enumAfter))
      case _: IntType =>
        if (t.vt == VFloat) throw new AdaUnsupported("value instance of an integer type whose expression is a float")
        accessor(o, nm, KT + "S64", pre, None, t.code, params,
          describe(List(s"Instance $kq, an integer (a Kaitai.Types.S64)"), v.doc, computed))
      case _: BooleanType =>
        accessor(o, nm, "Boolean", pre, None, t.code, params, describe(List(s"Instance $kq, a boolean"), v.doc, computed))
      case _: FloatType =>
        accessor(o, nm, "Kaitai.Floats.F64", pre, None, tr.asFloat(t).code, params,
          describe(List(s"Instance $kq, a float (a Kaitai.Floats.F64)"), v.doc, computed))
      case _: BytesType | _: StrType =>
        t.vt match {
          case VBytes | VStr(_) =>
            accessor(o, nm, KT + "Slice", pre, Some(s"${KT}Within ($nm'Result, Buffer)"), t.code, params,
              describe(List(s"Instance $kq, ${whatIs(v.dataType)}, as a slice of the buffer"), v.doc, computed))
          case _ => throw new AdaUnsupported("value instance of bytes or string that is not a field")
        }
      case ut: UserType =>
        t.vt match {
          case VUser(c) if (c eq ut.classSpec.get) && t.code.matches("This\\..*(_First_Element|_Last_Element|_Element_[0-9]+)") =>
            val pkg = packageOf(c)
            val belongs = if (hasBelongs(c)) s" and then $pkg.Belongs_To ($nm'Result, Buffer)" else ""
            accessor(o, nm, s"$pkg.T", pre, Some(s"$pkg.Valid ($nm'Result)$belongs"), t.code, params,
              describe(List(s"Instance $kq, a value of the type ${q(c.nameAsStr)}"), v.doc, computed))
          case _ => throw new AdaUnsupported("value instance of a user type that is not a field or an element of a repetition")
        }
      case other => throw new AdaUnsupported(s"value instance of type $other")
    }
    tr.buffer = saveBuf
  }

  private def genParseInstance(cs: ClassSpec, p: ParseInstanceSpec, o: Out): Unit = {
    tr.inParseInstance = true
    try genParseInstanceBody(cs, p, o)
    finally tr.inParseInstance = false
  }

  private def genParseInstanceBody(cs: ClassSpec, p: ParseInstanceSpec, o: Out): Unit = {
    val nm = plain(idRaw(p.id))
    val bs = base(idRaw(p.id))
    val path = p.path
    if (p.cond.repeat != NoRepeat) throw new AdaUnsupported("parse instance with `repeat`")
    if (AdaTranslator.hasProcess(p.dataType)) throw new AdaUnsupported("parse instance with `process`")
    if (p.pos.isEmpty) throw new AdaUnsupported("parse instance without `pos`")
    p.dataType match {
      case _: SwitchType => throw new AdaUnsupported("parse instance whose type depends on a value")
      case _ =>
    }
    val sc = new Scope
    val rc = RC("L", if (storesOrder(cs)) "This.Order" else "", sc, path)
    val rootIo = p.io match {
      case None => false
      case Some(e) if isRootIoExpr(e) => true
      case Some(_) => throw new AdaUnsupported("`io` other than `_root._io`")
    }
    val dt = p.dataType
    val (resT, _) = storedType(dt, path)
    val belongsOk = hasBelongs(cs)
    val pre0 = if (belongsOk) s"Valid (This) and then Belongs_To (This, Buffer)" else "Valid (This)"
    var pre = pre0
    p.cond.ifExpr.foreach { c =>
      val saved = tr.buffer
      val t = Tplain(c, rc.copy(s = "L"))
      // Has_X as a value instance function
      val gs = t.guards ++ List(if (t.prec >= 3) s"(${t.code})" else t.code)
      o.pub ++= ind(describe(List(s"True if the instance ${q(idRaw(p.id))} is there", "It has a condition (`if`) in the description, which is evaluated at every call"),
        DocSpec.EMPTY) ++ List(s"function ${hasNm(bs)} (This : T) return Boolean", "with Pre => Valid (This);", ""))
      o.privFuncs += s"function ${hasNm(bs)} (This : T) return Boolean"
      o.privFuncs += s"is (${gs.distinct.mkString("\n and then ")});"
      o.privFuncs += ""
      pre = s"$pre0 and then ${hasNm(bs)} (This)"
      if (t.usesBuffer) throw new AdaUnsupported("condition of a parse instance that needs the buffer")
    }
    val post = dt match {
      case ut: UserType =>
        val pkg = userPkg(ut); opTypes += "Status_Kind"
        Some(s"$pkg.Valid (Result) = (Outcome = ${KT}Success)" + (if (hasBelongs(ut.classSpec.get)) s" and then $pkg.Belongs_To (Result, Buffer)" else ""))
      case _: BytesType | _: StrType => Some(s"${KT}Within (Result, Buffer)")
      case _ => None
    }
    val spec = s"procedure $nm (This : T; Buffer : ${KT}Bytes; Result : out $resT; Outcome : out ${KT}Status_Kind)"
    o.unread += nm
    val k = idRaw(p.id)
    val instIs = dt match {
      case et: EnumType => s"${whatIs(dt)}, the number of a label of the enumeration ${q(et.enumSpec.get.name.last)}"
      case _: BytesType | _: StrType => s"${whatIs(dt)}, as a slice of the buffer"
      case _ => whatIs(dt)
    }
    val resultTag = dt match {
      case _: UserType => "The instance. Valid if and only if Outcome is Success"
      case _ => "The instance. It is meaningful only if Outcome is Success"
    }
    val instAfter = List("It has a position of its own in the data (`pos`), which Parse does not read: this procedure parses it at every call, and This does not keep it") ++
      (if (rootIo) List("It is read from the whole of Buffer (`io: _root._io`)") else Nil) ++
      (if (p.cond.ifExpr.isDefined) List(s"Requires ${hasNm(bs)}") else Nil)
    o.pub ++= ind(describe(List(s"Instance ${q(k)}, $instIs"), p.doc, instAfter) ++
      tag("param", "This", "The value that has the instance") ++
      tag("param", "Buffer", "The buffer that This was parsed from, unchanged") ++
      tag("param", "Result", resultTag) ++
      tag("param", "Outcome", "Success, or why the instance could not be parsed"))
    o.pub += s"   $spec"
    o.pub += s"   with Pre => $pre${post.map(x => s", Post => $x").getOrElse("")};"
    o.pub += ""
    // body
    val posT = T(p.pos.get, rc, "Pos")
    val seek = guarded(posT.guards, List(s"${KS}Seek (L, ${sizeCode(posT)});"), rc)
    val reads = readValue(dt, "Result", rc, defaultTarget = true) ++ p.valid.toList.flatMap(v => validate(v, dt, "Result", rc))
    val init = if (rootIo) s"L : ${KS}Stream := ${KS}Open (Buffer);" else s"L : ${KS}Stream := This.Io;"
    val bit = if (sc.bit) List(s"Bit : ${KT}U64;") else Nil
    val bodyStmts = seek ++ reads ++ List(s"Outcome := ${KS}Status (L);")
    val text = bodyStmts.mkString("\n")
    val unref = if (text.contains("This")) Nil else List("pragma Warnings (Off, This);")
    o.bodyAfter ++= List(s"$spec is") ++ ind(List(init) ++ sc.decls.toList ++ bit ++ unref) ++ List("begin") ++ ind(bodyStmts) ++ List(s"end $nm;", "")
  }

  private def isRootIoExpr(e: Ast.expr): Boolean = e match {
    case Ast.expr.Attribute(Ast.expr.Name(Ast.identifier(Identifier.ROOT)), Ast.identifier(Identifier.IO)) => true
    case _ => false
  }

  // -------------------------------------------------------------------- Parse

  private def genParseBody(cs: ClassSpec, o: Out, sc: Scope, params: String): List[String] = {
    val stmts = ListBuffer[String]()
    val decls = ListBuffer[String]()
    // a calculated byte order of a type that computes it itself
    val ownCalc: Option[CalcEndian] = cs.meta.endian match {
      case Some(ce: CalcEndian) if !containsParent(ce.on) => Some(ce)
      case _ => None
    }
    val rc = RC("S", if (storesOrder(cs)) "Order" else "", sc, cs.path)
    val pre = ListBuffer[String]()
    if (hasIo(cs)) pre += "This.Io := S;"
    keptParams(cs).foreach { p => pre += s"This.${plain(idRaw(p.id))} := ${paramName(idRaw(p.id))};" }
    refsOf(cs).foreach { r => pre += s"This.${r.adaName} := ${r.adaName};" }
    if (isRecursive(cs)) pre += "This.Depth := Depth;"
    ownCalc.foreach { ce =>
      decls += s"Order : ${KT}Byte_Order;"
      pre ++= guard(cs.path)(calcOrder(ce, "Order", rc))
    }
    if (storesOrder(cs)) pre += "This.Order := Order;"
    // a type without fields reads nothing: S is not modified
    val all = pre.toList ++ o.parse.toList
    val usesBuffer = all.exists(_.contains("Buffer"))
    val init = if (sc.needsInit || sc.passesThis) List("This := (others => <>);") else Nil
    val bit = if (sc.bit) List(s"Bit : ${KT}U64;") else Nil
    val unmod = if (cs.seq.isEmpty) List("pragma Unmodified (S);") else Nil
    val declAll = decls.toList ++ sc.decls.toList ++ bit ++ unmod
    List(s"procedure Parse ($params) is") ++ ind(declAll) ++ List("begin") ++
      ind(init ++ all ++ List(s"This.Is_Valid := ${KS}OK (S);")) ++ List("end Parse;")
  }

  // `Order` is a parameter of Parse when the caller computes it
}

object AdaClassCompiler extends LanguageCompilerStatic {
  override def getCompiler(tp: ClassTypeProvider, config: RuntimeConfig): LanguageCompiler = ???

  val KT = "Kaitai.Types."
  val KS = "Kaitai.Streams."
  val KB = "Kaitai.Byte_Arrays."
  val KStr = "Kaitai.Strings."
  val KW = "Kaitai.Writers."

  /** Names of local variables of Parse, which a parameter must not take */
  val ParamReserved: Set[String] = Set("sub", "bit", "element", "done", "value", "l", "result", "outcome", "position", "i", "start", "arg", "index", "kind", "raw", "target", "storage", "last", "inflated", "none")

  val Reserved: Set[String] = Set(
    // Ada reserved words
    "abort", "abs", "abstract", "accept", "access", "aliased", "all", "and", "array", "at", "begin", "body", "case",
    "constant", "declare", "delay", "delta", "digits", "do", "else", "elsif", "end", "entry", "exception", "exit", "for",
    "function", "generic", "goto", "if", "in", "interface", "is", "limited", "loop", "mod", "new", "not", "null", "of",
    "or", "others", "out", "overriding", "package", "parallel", "pragma", "private", "procedure", "protected", "raise",
    "range", "record", "rem", "renames", "requeue", "return", "reverse", "select", "separate", "some", "subtype",
    "synchronized", "tagged", "task", "terminate", "then", "type", "until", "use", "when", "while", "with", "xor",
    // names the generated code uses itself
    "t", "parse", "valid", "belongs_to", "next", "has_element", "remaining", "max_depth", "write", "this", "buffer", "s", "order",
    "is_valid", "io",
    // Standard
    "kaitai", "boolean", "true", "false", "natural", "positive", "integer", "string", "character", "standard"
  )
}
