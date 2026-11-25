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
  private lazy val importedNames: Set[String] = classSpecs.keys.map(k => base(k).toLowerCase).toSet

  private def isReserved(n: String): Boolean =
    Reserved.contains(n.toLowerCase) || n.toLowerCase == topAdaName.toLowerCase || importedNames.contains(n.toLowerCase)

  private def plain(raw: String): String = plainIn(provider.nowClass, raw)

  private def plainIn(cs: ClassSpec, raw: String): String = {
    val b = base(raw)
    if (isReserved(b) || raw.endsWith("_") || raw.contains("__") || derivedNames(cs).contains(b.toLowerCase)) b + "_Field"
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
      dt match {
        case st: SwitchType =>
          st.cases.values.foreach {
            case ut: UserType =>
              val y = base(ut.classSpec.get.name.last)
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

  private def valueInfo(cs: ClassSpec, v: ValueInstanceSpec): (Boolean, Boolean) =
    instInfo.getOrElseUpdate((cs.nameAsStr, v.id.name), {
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
    * The key `parent` gives one use of a type another parent, or none. Here the type that has the field passes the
    * values of `_parent`, so the key is rejected where the type of the field, or a type that it uses, needs them.
    */
  private def checkParentKey(): Unit = {
    def usesParent(c: ClassSpec, seen: ListBuffer[ClassSpec]): Boolean =
      !seen.exists(_ eq c) && {
        seen += c
        outsideExprs(c).exists(containsParent) || userTypesOf(c).exists(u => usesParent(u, seen))
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
      hasIo(cs)
  })

  private def dtHasRepeat(a: AttrLikeSpec): Boolean = true

  private def hasIo(cs: ClassSpec): Boolean =
    cs.instances.values.exists {
      case p: ParseInstanceSpec => p.io.isEmpty
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
    * The value of `_parent.x` (hops = 1), `_parent._parent.x` (hops = 2) or `_root.x`, which the parser of a
    * type gets from outside as a parameter. `path` names the member `x` and, for a value inside a nested
    * value, the members on the way to it.
    */
  case class Ref(root: Boolean, hops: Int, path: List[String]) {
    def source: String = (if (root) "_root" else List.fill(hops)("_parent").mkString(".")) + path.map("." + _).mkString
    def raw: String = (if (root) "root" else List.fill(hops)("parent").mkString("_")) + "_" + path.mkString("_")
    def adaName: String = base(raw)
  }

  private val refTypes = mutable.Map[(String, Ref), DataType]()

  private def classFile(cs: ClassSpec): String = cs.name.head

  /** The class that `_root` means in `cs`: the top-level type of the description of `cs`. */
  private def rootOf(cs: ClassSpec): ClassSpec = classSpecs.get(classFile(cs)).getOrElse(topClass)

  private lazy val usersMemo: Map[String, List[ClassSpec]] = {
    val m = mutable.LinkedHashMap[String, ListBuffer[ClassSpec]]()
    allClasses.foreach { c =>
      userTypesOf(c).foreach { u =>
        if (classFile(u) == classFile(c)) {
          val l = m.getOrElseUpdate(u.nameAsStr, ListBuffer())
          if (!l.exists(_ eq c)) l += c
        }
      }
    }
    m.map(kv => kv._1 -> kv._2.toList).toMap
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

  /** From class `from`, follow the members of `rest` as far as the value of a member that is not a nested value. */
  private def resolvePath(from: ClassSpec, rest: List[String]): Option[(List[String], DataType)] = {
    var c = from
    var consumed = List[String]()
    var remaining = rest
    while (remaining.nonEmpty) {
      val m = memberOpt(c, remaining.head).getOrElse(return None)
      consumed = consumed :+ remaining.head
      remaining = remaining.tail
      val repeated = m match { case a: AttrLikeSpec => a.cond.repeat != NoRepeat; case _ => false }
      m.dataType match {
        case ut: UserType if remaining.nonEmpty && !repeated && ut.classSpec.isDefined => c = ut.classSpec.get
        case dt => return Some((consumed, dt))
      }
    }
    None
  }

  /** The reference that the chain starts with, its type, and how many names of the chain it covers. */
  private def refPrefix(cs: ClassSpec, base: String, attrs: List[String]): (Ref, DataType, Int) =
    if (base == Identifier.ROOT) {
      val root = rootOf(cs)
      resolvePath(root, attrs) match {
        case Some((p, dt)) => (Ref(root = true, 0, p), dt, p.size)
        case None => unsupported(s"`_root.${attrs.mkString(".")}`: no such member in type ${root.nameAsStr}")
      }
    } else {
      val hops = 1 + attrs.takeWhile(_ == Identifier.PARENT).size
      val rest = attrs.dropWhile(_ == Identifier.PARENT)
      val cands = ancestors(cs, hops)
      if (cands.isEmpty)
        unsupported(s"`${List.fill(hops)("_parent").mkString(".")}` in type ${cs.nameAsStr}, which no type of the description has as a field")
      cands.view.flatMap(c => resolvePath(c, rest)).headOption match {
        case Some((p, dt)) => (Ref(root = false, hops, p), dt, hops - 1 + p.size)
        case None => unsupported(s"`${(List.fill(hops)("_parent") ++ rest).mkString(".")}`: no such member in the type that has the field")
      }
    }

  private def procExprs(p: Option[ProcessExpr]): List[Ast.expr] = p match {
    case Some(ProcessXor(k)) => List(k)
    case Some(ProcessRotate(_, k)) => List(k)
    case Some(ProcessCustom(_, args)) => args.toList
    case _ => Nil
  }

  private def dtExprs(dt: DataType): List[Ast.expr] = dt match {
    case BytesLimitType(size, _, _, _, proc) => size :: procExprs(proc)
    case BytesEosType(_, _, _, proc) => procExprs(proc)
    case BytesTerminatedType(_, _, _, _, proc) => procExprs(proc)
    case StrFromBytesType(bt, _, _) => dtExprs(bt)
    case ut: UserTypeFromBytes => ut.args.toList ++ dtExprs(ut.bytes) ++ procExprs(ut.process)
    case ut: UserType => ut.args.toList
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

  private def scanRefs(cs: ClassSpec, expr: Ast.expr): List[(Ref, DataType)] = {
    val out = ListBuffer[(Ref, DataType)]()
    def walk(e: Ast.expr): Unit = chainOf(e) match {
      case Some((base, attrs)) =>
        if (base == Identifier.ROOT && attrs.headOption.contains(Identifier.IO)) ()
        else if (attrs.isEmpty) unsupported(s"`$base` used as a value")
        else if (base == Identifier.PARENT && attrs.headOption.contains(Identifier.IO)) unsupported("`_parent._io`")
        else if (base == Identifier.ROOT && isRecursive(rootOf(cs)))
          // The value that a nested top-level value would need is the one of the outermost value, not its own.
          unsupported("`_root` in a description whose top-level type contains itself")
        else if (base == Identifier.ROOT && (rootOf(cs) eq cs)) ()
        else {
          val (r, dt, _) = refPrefix(cs, base, attrs)
          out += ((r, dt))
        }
      case None =>
        e match {
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
    }
    walk(expr)
    out.toList
  }

  private def refParamType(dt: DataType, r: Ref): String = dt match {
    case _: IntType | _: EnumType | _: BooleanType => intAda(dt)
    case other => unsupported(s"`${r.source}` has the type $other; only integers, booleans and enumerations can be passed")
  }

  private lazy val refsMemo: Map[String, List[Ref]] = {
    val refs = mutable.LinkedHashMap[String, ListBuffer[Ref]]()
    allClasses.foreach(c => refs(c.nameAsStr) = ListBuffer())
    def add(c: ClassSpec, r: Ref, dt: DataType): Boolean =
      if (refs(c.nameAsStr).contains(r)) false
      else {
        guard(c.path)(refParamType(dt, r))
        refs(c.nameAsStr) += r
        refTypes((c.nameAsStr, r)) = dt
        true
      }
    allClasses.foreach { c =>
      guard(c.path) {
        outsideExprs(c).foreach(e => scanRefs(c, e).foreach { case (r, dt) => add(c, r, dt) })
      }
    }
    var changed = true
    while (changed) {
      changed = false
      allClasses.foreach { c =>
        userTypesOf(c).foreach { b =>
          refs(b.nameAsStr).toList.foreach { r =>
            val dt = refTypes((b.nameAsStr, r))
            if (r.root) {
              if (!(rootOf(c) eq c) && (rootOf(c) eq rootOf(b))) changed |= add(c, r, dt)
            } else if (r.hops > 1) changed |= add(c, r.copy(hops = r.hops - 1), dt)
          }
        }
      }
    }
    allClasses.foreach { c =>
      if ((rootOf(c) eq c) && refs(c.nameAsStr).exists(!_.root))
        fail(c.path, s"`${refs(c.nameAsStr).filter(!_.root).head.source}` in the top-level type of a description, which has no parent")
    }
    refs.map(kv => kv._1 -> kv._2.toList).toMap
  }

  private def refsOf(cs: ClassSpec): List[Ref] = refsMemo.getOrElse(cs.nameAsStr, Nil)

  override def outsideRef(cs: ClassSpec, e: Ast.expr): Option[Either[(String, DataType), Ast.expr]] =
    chainOf(e).flatMap { case (base, attrs) =>
      if (attrs.isEmpty) None
      else if (attrs.head == Identifier.IO) None
      else if (base == Identifier.ROOT && (rootOf(cs) eq cs))
        Some(Right(attrs.tail.foldLeft[Ast.expr](Ast.expr.Name(Ast.identifier(attrs.head)))((v, a) => Ast.expr.Attribute(v, Ast.identifier(a)))))
      else {
        val (r, dt, n) = refPrefix(cs, base, attrs)
        if (n == attrs.size) Some(Left((r.adaName, dt))) else None
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

  /** Position in the seq of the field that is being generated; larger than any for an instance. */
  private var curSeqIdx: Int = Int.MaxValue

  // ------------------------------------------------------------ output helpers

  private def ind(lines: Seq[String], n: Int = 1): List[String] =
    lines.toList.map(l => if (l.isEmpty) l else ("   " * n) + l)

  private def wrapComment(text: String, width: Int = 90): List[String] =
    text.split("\n").toList.flatMap { para =>
      val words = para.trim.split("\\s+").filter(_.nonEmpty).toList
      val lines = ListBuffer[String]()
      var cur = ""
      words.foreach { w =>
        if (cur.isEmpty) cur = w
        else if (cur.length + 1 + w.length > width) { lines += cur; cur = w }
        else cur = cur + " " + w
      }
      if (cur.nonEmpty) lines += cur
      if (lines.isEmpty) List("") else lines.toList
    }.map(l => if (l.isEmpty) "--" else s"--  $l")

  private def docLines(doc: DocSpec): List[String] =
    doc.summary.map(wrapComment(_)).getOrElse(Nil)

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
    val bodyAfter = ListBuffer[String]()
    val write = ListBuffer[String]()
    val wscope = new Scope
  }

  private def T(e: Ast.expr, rc: RC): ATr = {
    tr.buffer = Some("Buffer")
    tr.io = Some(rc.s)
    tr.thisName = "This"
    tr.iterator = None
    tr.knownValid = Set()
    guard(rc.path)(tr.translate(e))
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
        val t = T(size, rc)
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
    val conds = labeled.map { case (k, v) => (T(Ast.expr.Compare(ce.on, Ast.cmpop.Eq, k), rc), v) }
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

  /** Statements before the call, and the arguments of the call (including the byte order). */
  private def callArgs(ut: UserType, rc: RC): (List[String], List[String]) = {
    val callee = ut.classSpec.get
    if (callee.meta.isOpaque) throw new AdaUnsupported(s"opaque type ${callee.nameAsStr}")
    if (ut.args.size != callee.params.size)
      throw new AdaUnsupported(s"type ${callee.nameAsStr} takes ${callee.params.size} parameters")
    val pre = ListBuffer[String]()
    val args = ListBuffer[String]()
    val (ostm, oarg) = orderArg(callee, rc)
    pre ++= ostm
    oarg.foreach(args += _)
    ut.args.zip(callee.params).foreach { case (a, p) =>
      val t = T(a, rc)
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
      val ada = refParamType(dt, r)
      val p = ParamDefSpec(callee.path, NamedIdentifier(r.raw), dt)
      if (r.root && (rootOf(callee) ne rootOf(caller)))
        unsupported(s"type ${callee.nameAsStr} of another description uses `_root`")
      val own = if (r.root) rootOf(caller) eq caller else r.hops == 1
      val t: ATr =
        if (own) {
          val expr = r.path.tail.foldLeft[Ast.expr](Ast.expr.Name(Ast.identifier(r.path.head)))((v, a) => Ast.expr.Attribute(v, Ast.identifier(a)))
          memberDeps(caller, expr).foreach { n =>
            val j = caller.seq.indexWhere(a => idRaw(a.id) == n)
            if (j >= curSeqIdx)
              unsupported(s"`${r.source}` of type ${callee.nameAsStr} is the field `$n`, which is parsed after the field that needs it")
          }
          T(expr, rc)
        } else tr.fromValue(dt, s"This.${(if (r.root) r else r.copy(hops = r.hops - 1)).adaName}", Nil)
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
    selfGuard(ut, pre ++ List(s"${qualOf(ut.classSpec.get)}Parse (Buffer, ${rc.s}, ${(args :+ target).mkString(", ")});"), target, rc)
  }

  private def userCallSub(ut: UserTypeFromBytes, target: String, rc: RC): List[String] = {
    if (ut.process.isDefined) throw new AdaUnsupported("`process`")
    val (pre, args) = callArgs(ut, rc)
    val sub = rc.scope.fresh("Sub")
    rc.scope.decls += s"$sub : ${KS}Stream;"
    val mk = ut.bytes match {
      case BytesLimitType(size, None, false, None, None) =>
        val t = T(size, rc)
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
    selfGuard(ut, pre ++ mk ++ List(s"${qualOf(ut.classSpec.get)}Parse (Buffer, $sub, ${(args :+ target).mkString(", ")});", s"${KS}Join (${rc.s}, $sub);") ++ reset, target, rc)
  }

  // ---------------------------------------------------------------- validation

  private val UnderscoreName = Ast.expr.Name(Ast.identifier(Identifier.ITERATOR))

  private def validate(v: ValidationSpec, dt: DataType, target: String, rc: RC): List[String] = {
    def check(cond: Ast.expr, reason: String): List[String] = {
      tr.buffer = Some("Buffer")
      tr.io = Some(rc.s)
      tr.thisName = "This"
      tr.knownValid = Set()
      tr.iterator = Some((dt, target))
      val t = guard(rc.path)(tr.translate(cond))
      tr.iterator = None
      guarded(t.guards, List(s"if ${t.code} then", "   " + failStmt(rc, reason), "end if;"), rc)
    }
    def cmp(op: Ast.cmpop, e: Ast.expr) = Ast.expr.Compare(UnderscoreName, op, e)
    v match {
      case ValidationEq(e) => check(cmp(Ast.cmpop.NotEq, e), "Validation_Not_Equal")
      case ValidationMin(e) => check(cmp(Ast.cmpop.Lt, e), "Validation_Less_Than")
      case ValidationMax(e) => check(cmp(Ast.cmpop.Gt, e), "Validation_Greater_Than")
      case ValidationRange(lo, hi) =>
        check(cmp(Ast.cmpop.Lt, lo), "Validation_Less_Than") ++ check(cmp(Ast.cmpop.Gt, hi), "Validation_Greater_Than")
      case ValidationAnyOf(values) =>
        check(Ast.expr.BoolOp(Ast.boolop.And, values.map(x => cmp(Ast.cmpop.NotEq, x))), "Validation_Not_Any_Of")
      case ValidationInEnum() =>
        dt match {
          case et: EnumType =>
            val t = fromValueChecked(dt, target, rc)
            val chk = s"${enumTypeName(et.enumSpec.get).split('.').dropRight(1).mkString(".")}"
            val isFn = (if (chk.isEmpty) "" else chk + ".") + "Is_" + enumTy(et.enumSpec.get)
            guarded(t.guards, List(s"if not $isFn (${t.code}) then", "   " + failStmt(rc, "Validation_Not_In_Enum"), "end if;"), rc)
          case _ => throw new AdaUnsupported("`in-enum` on something that is not an enumeration")
        }
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

  /** `with` clauses for the packages of other descriptions that the lines use and that are not named yet */
  private def importedWiths(lines: List[String], known: List[String] = Nil): List[String] = {
    val clean = lines.map(l => l.takeWhile(_ != '-')).mkString("\n")
    val ws = classSpecs.keys.toList.filter(_ != topClass.name.head).map(base).sorted.distinct
      .filter(p => ("\\b" + p + "\\.").r.findFirstIn(clean).isDefined)
      .map(p => s"with $p;").filterNot(known.contains)
    if (ws.isEmpty) Nil else ws
  }

  private val LibPackages = List("Streams", "Types", "Arithmetic", "Decoding", "Strings", "Byte_Arrays", "Floats", "Processing", "Zlib", "Writers")

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

  private val UseTypes = List("U8", "U16", "U32", "U64", "S8", "S16", "S32", "S64", "Length", "Slice", "Status_Kind", "Byte_Order")

  /** Generates specification and body of a class, as lines of a library unit or a nested package. */
  private def genClass(cs: ClassSpec): (List[String], List[String]) = {
    if (cs.meta.isOpaque) fail(cs.path, s"opaque type ${cs.nameAsStr}")
    val isTop = cs.upClass.isEmpty && cs.name.size == 1
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
    childOut.foreach { case (c, s, _) =>
      specB += s"--  type ${c.nameAsStr}"
      specB += ""
      specB ++= s
      specB += ""
    }

    provider.nowClass = cs
    val o = new Out
    val sc = new Scope
    genMembers(cs, o, sc)

    // ---- T and its public interface
    val orderPar = if (hasOrderParam(cs)) List(s"Order : ${KT}Byte_Order") else Nil
    val paramDecls = cs.params.map(p => s"${paramName(idRaw(p.id))} : ${guard(p.path)(paramAda(p))}")
    val refDecls = refsOf(cs).map(r => s"${r.adaName} : ${refParamType(refTypes((cs.nameAsStr, r)), r)}")
    val depthDecl = if (isRecursive(cs)) List("Depth : Natural") else Nil
    val parseParams = (List(s"Buffer : ${KT}Bytes", s"S : in out ${KS}Stream") ++ orderPar ++ paramDecls ++ refDecls ++ depthDecl :+ "This : out T").mkString("; ")
    val parseNotes =
      (if (refsOf(cs).isEmpty) Nil
       else wrapComment(refsOf(cs).map(r => s"${r.adaName} is ${r.source}").mkString(", ") + ".")) ++
        (if (!isRecursive(cs)) Nil
         else wrapComment("Depth is the number of levels of nesting that are accepted below this value; deeper ones make the stream fail with Limit_Exceeded."))
    val belongsOk = hasBelongs(cs)
    val writeParams = (if (belongsOk) s"Buffer : ${KT}Bytes; " else "") + s"This : T; Target : in out ${KT}Bytes; W : in out ${KW}Writer"

    specB += "type T is private;"
    specB += ""
    specB += "function Valid (This : T) return Boolean;"
    specB += ""
    if (belongsOk) {
      specB += s"function Belongs_To (This : T; Buffer : ${KT}Bytes) return Boolean;"
      specB += ""
    }
    specB ++= parseNotes
    specB += s"procedure Parse ($parseParams)"
    specB += "with"
    specB += s"  Pre  => ${KS}Is_Valid (S, Buffer),"
    specB += s"  Post => ${KS}Is_Valid (S, Buffer) and then ${KS}Advanced (S'Old, S) and then Valid (This) = ${KS}OK (S)" +
      (if (belongsOk) " and then Belongs_To (This, Buffer)" else "") + (if (isRecursive(cs)) "," else ";")
    if (isRecursive(cs)) specB += "  Subprogram_Variant => (Decreases => Depth, Decreases => 1);"
    specB += ""
    specB ++= o.pub
    if (config.readWrite) {
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
    val paramComps = cs.params.flatMap(p => paramComponent(p))
    val refComps = refsOf(cs).map { r =>
      val t = refParamType(refTypes((cs.nameAsStr, r)), r)
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
    cs.params.foreach(p => specB ++= genParamAccessor(p, cs))
    specB ++= ind(o.privFuncs.toList)
    // ---- Parse body
    val bodyParse = genParseBody(cs, o, sc, parseParams)

    val specOut = ListBuffer[String]()
    if (isTop) {
      specOut += s"package $pkgName"
      specOut += "  with SPARK_Mode, Always_Terminates"
      specOut += "is"
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
      docLines(cs.doc).foreach(l => specOut += l)
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
    bodyOut ++= ind(bodyB.toList)
    bodyOut += ""
    bodyOut += s"end $pkgName;"
    (specOut.toList.map(_.replaceAll("\\s+$", "")), bodyOut.toList.map(_.replaceAll("\\s+$", "")))
  }

  private def paramComponent(p: ParamDefSpec): List[String] = {
    val t = guard(p.path)(paramAda(p))
    List(s"${plain(idRaw(p.id))} : $t := ${defaultOf(t)};")
  }

  private def genParamAccessor(p: ParamDefSpec, cs: ClassSpec): List[String] = Nil

  // enumerations

  private def genEnum(e: EnumSpec): List[String] = {
    val n = enumTy(e)
    val entries = e.map.toList
    entries.foreach { case (v, _) =>
      if (v < AdaTranslator.S64Min || v > AdaTranslator.S64Max)
        fail(e.path, s"enum value $v does not fit into 64 bits")
    }
    val lits = entries.map { case (_, s) => enumLit(e, s.name) }
    val values = entries.map(_._1.toString)
    val out = ListBuffer[String]()
    out ++= docLines(DocSpec(Some(s"enum ${e.name.last}"), Nil))
    out += s"type $n is (${lits.mkString(", ")});"
    out += ""
    out += s"function Is_$n (Value : ${KT}S64) return Boolean"
    out += s"is (Value in ${values.mkString(" | ")});"
    out += ""
    out += s"function To_$n (Value : ${KT}S64) return $n"
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
    out += s"function To_Integer (Value : $n) return ${KT}S64"
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
        val t = T(size, rc)
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
    s"${qualOf(callee)}Write ($buf$target, Target, $writer);"
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
            val t = T(size, rc)
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
      if (first && a.cond.repeat == NoRepeat && (a.dataType match {
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
      case other => throw new AdaUnsupported(s"repetition of $other")
    }
    val isSlice = !dt.isInstanceOf[UserType]
    val body = writeValue(dt, "Element", rc)
    val cur = s"${bs}_Cursor"
    val write =
      if (isSlice) body
      else List(s"if ${elPkg}Valid (Element) then") ++ ind(body) ++ List("else", "   --  The buffer is not what was parsed",
        s"   ${KW}Fail (W, ${KT}Validation_Expr);", "end if;")
    List("declare", s"   Position : $cur := ${bs}_First (This);", s"   Element  : $elT;", "begin") ++
      ind(List(
        "while Has_Element (Position) loop",
        "   pragma Loop_Invariant (Belongs_To (Position, Buffer));",
        s"   pragma Loop_Invariant (${KW}Is_Valid (W, Target) and then ${KW}Same_Window (W'Loop_Entry, W));",
        "   pragma Loop_Variant (Decreases => Remaining (Position));",
        "   Next (Buffer, This, Position, Element);") ++ ind(write) ++ List("end loop;")) ++ List("end;")
  }

  private def genMembers(cs: ClassSpec, o: Out, sc: Scope): Unit = {
    val rc = RC("S", if (storesOrder(cs)) "Order" else "", sc, cs.path)
    // parameters
    cs.params.foreach { p => guard(p.path)(genParamMember(p, cs, o, rc)) }
    // sequence
    cs.seq.zipWithIndex.foreach { case (a, i) =>
      val rcA = rc.copy(path = a.path)
      curSeqIdx = i
      guard(a.path)(genSeqAttr(cs, a, i == 0, o, rcA))
      if (config.readWrite) guard(a.path)(genWriteAttr(cs, a, i == 0, o, writeCtx(cs, o.wscope, a.path)))
    }
    // instances
    curSeqIdx = Int.MaxValue
    cs.instances.values.foreach { inst =>
      provider.nowClass = cs
      inst match {
        case v: ValueInstanceSpec => guard(v.path)(genValueInstance(cs, v, o))
        case p: ParseInstanceSpec => guard(p.path)(genParseInstance(cs, p, o))
      }
    }
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
        enumAccessors(o, nm, bs, ada, et, "Valid (This)", docLines(p.doc))
      case _ =>
        accessor(o, nm, ada, "Valid (This)", None, s"This.$nm", comment = docLines(p.doc))
    }
  }

  private def enumAccessors(o: Out, nm: String, bs: String, ada: String, et: EnumType, pre: String, comment: List[String], compName: Option[String] = None): Unit = {
    val comp = compName.getOrElse(nm)
    val spec = et.enumSpec.get
    val tyName = enumTypeName(spec)
    val pkgPrefix = tyName.split('.').dropRight(1).mkString(".")
    val q = if (pkgPrefix.isEmpty) "" else pkgPrefix + "."
    val t = guard(Nil)(tr.fromValue(et, s"${bs}_Value (This)", Nil))
    accessor(o, s"${bs}_Value", ada, pre, None, s"This.$comp", comment = comment)
    val enumPre = (List(pre) ++ t.guards ++ List(s"${q}Is_${enumTy(spec)} (${t.code})")).mkString(" and then ")
    accessor(o, nm, tyName, enumPre, None, s"${q}To_${enumTy(spec)} (${t.code.replace(s"${bs}_Value (This)", s"This.$comp")})")
  }

  // ----------------------------------------------------------------- seq attrs

  private def hasCond(a: AttrLikeSpec): Boolean = a.cond.ifExpr.isDefined

  private def wrapCond(a: AttrSpec, hasName: Option[String], stmts: List[String], rc: RC): List[String] =
    a.cond.ifExpr match {
      case None => stmts
      case Some(c) =>
        val t = T(c, rc)
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
      o.pub ++= ind(List(s"function ${hasNm(bs)} (This : T) return Boolean", "with Pre => Valid (This);", ""))
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
      if (first && a.cond.repeat == NoRepeat && (a.dataType match {
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
      if (a.cond.repeat != NoRepeat) throw new AdaUnsupported("`valid` on a repeated field")
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
    proc match {
      case ProcessCustom(name, _) => unsupported(s"custom `process: ${name.mkString(".")}`")
      case _ =>
    }
    if (a.valid.isDefined) unsupported("`valid` on a field with `process`")
    val (pre, hasName) = condParts(cs, a, o)
    val raw = s"This.$nm"
    o.comps += s"$nm : ${KT}Slice;"
    o.belongs += s"${KT}Within ($raw, Buffer)"
    opTypes += "Length"
    val what = if (userT.isDefined) s"$nm: kept as it is in the input. $nm undoes the processing into Storage and parses the value from there, so that what the value refers to lies in Storage and not in Buffer."
               else s"$nm: kept as it is in the input. $nm undoes the processing and writes the result to an array of the caller."
    accessor(o, s"${bs}_Raw", KT + "Slice", pre, None, raw, comment = docLines(a.doc) ++ wrapComment(what))
    o.parse ++= wrapCond(a, if (hasName.isEmpty) None else Some(hasName), readBytes(bytesT, raw, rc, defaultTarget = false), rc)

    // the procedure
    val sc = new Scope
    val rcP = RC("Sub", if (storesOrder(cs)) "This.Order" else "", sc, a.path)
    val rcKey = RC("Unavailable_Stream", if (storesOrder(cs)) "This.Order" else "", sc, a.path)
    val src = s"Buffer ($raw.First .. $raw.Last)"
    val isZlib = proc == ProcessZlib
    val zlibKinds = "Kaitai.Zlib."
    // the call of the processing from src into dst, and the conditions under which it is defined
    def processCall(dst: String): (List[String], List[String]) = proc match {
      case ProcessXor(key) =>
        val t = T(key, rcKey)
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
        val t = T(amount, rcKey)
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
        val params = s"Buffer : ${KT}Bytes; This : T; Target : in out ${KT}Bytes; Last : out ${KT}Length; Outcome : out ${KT}Status_Kind"
        val post =
          if (isZlib)
            s"Last >= Target'First - 1 and then Last - (Target'First - 1) <= ${KT}Length (Target'Length) and then (if Outcome /= ${KT}Success then Last = Target'First - 1)"
          else s"(if Outcome = ${KT}Success then Last = Target'First + ${KT}Size (${bs}_Raw (This)) - 1 else Last = Target'First - 1)"
        opTypes += "Status_Kind"
        o.pub ++= ind(List(
          s"procedure $nm ($params)", "with",
          s"  Pre  => $pre and then Belongs_To (This, Buffer) and then Target'First >= 1,",
          s"  Post => $post;", ""))
        val stmts: List[String] =
          if (isZlib)
            List(s"${zlibKinds}Inflate ($src, Target, Last, Inflated);") ++ outcomeOfZlib
          else {
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
        val params = s"Buffer : ${KT}Bytes; This : T; Storage : in out ${KT}Bytes; Result : out ${userPkg(ut)}.T; Outcome : out ${KT}Status_Kind"
        opTypes += "Status_Kind"
        o.pub ++= ind(List(
          s"procedure $nm ($params)", "with",
          s"  Pre  => $pre and then Belongs_To (This, Buffer) and then Storage'First >= 1,",
          s"  Post => $pkg" + s"Valid (Result) = (Outcome = ${KT}Success)" + (if (belongsOk) s" and then ${pkg}Belongs_To (Result, Storage);" else ";"), ""))
        val dst = "Storage (Storage'First .. Last)"
        val (pcs, args) = callArgs(ut, rcP)
        val parseStmts = List(s"Sub := ${KS}Open (Storage (Storage'First .. Last));") ++ pcs ++
          List(s"${pkg}Parse (Storage, Sub, ${(args :+ "Result").mkString(", ")});", s"Outcome := ${KS}Status (Sub);")
        val stmts: List[String] =
          if (isZlib)
            List(s"${zlibKinds}Inflate ($src, Storage, Last, Inflated);", "case Inflated is", s"   when ${zlibKinds}Done =>") ++ ind(parseStmts, 2) ++
              List(s"   when ${zlibKinds}Corrupt =>", "      Result := None;", s"      Outcome := ${KT}Illegal_Sequence;",
                s"   when ${zlibKinds}Target_Full =>", "      Result := None;", s"      Outcome := ${KT}Capacity_Exceeded;", "end case;")
          else {
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
    o.pub ++= ind(docLines(a.doc) ++ List(s"--  $nm: not kept, but parsed again when asked for", ""))
    o.pub ++= ind(List(
      s"procedure $nm (Buffer : ${KT}Bytes; This : T; Result : out T; Outcome : out ${KT}Status_Kind)",
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
      s"procedure $nm (Buffer : ${KT}Bytes; This : T; Result : out T; Outcome : out ${KT}Status_Kind) is",
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
    val comment = docLines(a.doc)
    o.comps += s"$nm : $stored${default.map(d => s" := $d").getOrElse("")};"
    val target = s"This.$nm"
    dt match {
      case et: EnumType => enumAccessors(o, nm, bs, stored, et, pre, comment)
      case FloatMultiType(w, _) =>
        val fl = if (w.width == 4) "Kaitai.Floats.F32" else "Kaitai.Floats.F64"
        accessor(o, s"${bs}_Bits", stored, pre, None, s"This.$nm", comment = comment)
        accessor(o, nm, fl, s"$pre and then Kaitai.Floats.Is_Finite (${bs}_Bits (This))", None,
          s"Kaitai.Floats.To_${if (w.width == 4) "F32" else "F64"} (This.$nm)")
      case ut: UserType =>
        val pkg = userPkg(ut)
        accessor(o, nm, stored, pre, Some(s"$pkg.Valid ($nm'Result)"), s"This.$nm", comment = comment)
        o.valid += validWrap(a, s"$pkg.Valid (This.$nm)")
        if (hasBelongs(ut.classSpec.get)) o.belongs += s"$pkg.Belongs_To (This.$nm, Buffer)"
      case _: BytesType | _: StrType =>
        accessor(o, nm, stored, pre, None, s"This.$nm", comment = comment)
        o.belongs += s"${KT}Within (This.$nm, Buffer)"
      case _ =>
        accessor(o, nm, stored, pre, None, s"This.$nm", comment = comment)
    }
    val reads = readValue(dt, target, rc) ++ a.valid.toList.flatMap(v => validate(v, dt, target, rc))
    o.parse ++= firstAlign
    o.parse ++= wrapCond(a, if (hasName.isEmpty) None else Some(hasName), reads, rc)
  }

  // ---------------------------------------------------------------- switches

  private def isIntCase(dt: DataType): Boolean = dt match {
    case _: IntType | _: EnumType => true
    case _ => false
  }

  private def genSwitch(cs: ClassSpec, a: AttrSpec, st: SwitchType, o: Out, rc: RC): Unit = {
    val nm = plain(idRaw(a.id))
    val bs = base(idRaw(a.id))
    val cases = st.cases.toList
    if (cases.exists(c => AdaTranslator.hasProcess(c._2))) unsupported("`process` in a field whose type depends on a value")
    if (cases.exists { case (_, ut: UserType) => ut.classSpec.get eq cs; case _ => false })
      unsupported("a field whose type depends on a value and can be the type itself")
    val elseCase = cases.find(_._1 == SwitchType.ELSE_CONST).map(_._2)
    val labeled = cases.filter(_._1 != SwitchType.ELSE_CONST)
    val allInt = cases.forall(c => isIntCase(c._2))
    val onT = T(st.on, rc)
    val (pre, hasName) = condParts(cs, a, o)
    val comment = docLines(a.doc)

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
        case VStr(_) | VStrLit(_) =>
          val lines = ListBuffer[String]()
          others.zipWithIndex.foreach { case ((Some(k), stmts), i) =>
            val c = T(Ast.expr.Compare(st.on, Ast.cmpop.Eq, k), rc)
            lines += s"${if (i == 0) "if" else "elsif"} ${c.code} then"
            lines ++= ind(stmts)
            case _ =>
          }
          if (others.isEmpty) elseB else {
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
        o.pub ++= ind(List(s"function ${hasNm(bs)} (This : T) return Boolean", "with Pre => Valid (This);", ""))
        o.privFuncs += s"function ${hasNm(bs)} (This : T) return Boolean"
        o.privFuncs += s"is (This.${hasNm(bs)});"
        o.privFuncs += ""
        pre2 = s"Valid (This) and then ${hasNm(bs)} (This)"
      }
      o.comps += s"$nm : $adaT := 0;"
      accessor(o, nm, adaT, pre2, None, s"This.$nm", comment = comment)
      val branches: List[(Option[Ast.expr], List[String])] =
        labeled.map { case (k, dt) => (Some(k), intBranch(dt, nm, adaT, adaPlain, hasN, rc, a)) } ++
          elseCase.toList.map(dt => (None, intBranch(dt, nm, adaT, adaPlain, hasN, rc, a)))
      if (elseCase.isEmpty) rc.scope.needsInit = true
      o.parse ++= wrapCond(a, if (hasCond(a)) Some(hasName) else None, choose(branches), rc)
      return
    }

    // variants
    val variants = switchVariants(st)
    def variantOf(dt: DataType): String = variants.find(_._1 == dt).get._2
    val kindT = s"${bs}_Kind"
    val varT = s"${bs}_Variant"
    val none = s"${bs}_Is_None"
    val lits = variants.toList.map { case (_, n) => s"${bs}_Is_$n" } :+ none
    o.pub ++= ind(List(s"type $kindT is (${lits.mkString(", ")});", ""))
    accessor(o, s"${bs}_Case", kindT, pre, None, s"This.$nm.Kind", comment = comment)
    variants.foreach { case (dt, n) =>
      val (ty, post, extra) = dt match {
        case ut: UserType => (userPkg(ut) + ".T", Some(s"${userPkg(ut)}.Valid (${bs}_As_$n'Result)"), "")
        case _ => (KT + "Slice", None, "")
      }
      accessor(o, s"${bs}_As_$n", ty, s"$pre and then ${bs}_Case (This) = ${bs}_Is_$n", post, s"This.$nm.$n")
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

  /** The variants of a switch that is not all integers, in order: the type of the case and the name `Is_<Name>` is built from. */
  def switchVariants(st: SwitchType): List[(DataType, String)] = {
    val variants = ListBuffer[(DataType, String)]()
    val usedNames = mutable.Set[String]()
    st.cases.toList.foreach { case (_, dt) =>
      if (!variants.exists(_._1 == dt)) {
        val baseName = dt match {
          case ut: UserType => base(ut.classSpec.get.name.last)
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

  private def genRepeat(cs: ClassSpec, a: AttrSpec, rep: RepeatSpec, o: Out, rc: RC): Unit = {
    val nm = plain(idRaw(a.id))
    val bs = base(idRaw(a.id))
    val dt = a.dataType
    val (pre, hasName) = condParts(cs, a, o)
    val comment = docLines(a.doc)
    val hasOpt = if (hasName.isEmpty) None else Some(hasName)
    AdaTranslator.fixedElement(dt) match {
      case Some(size) => genRepeatSlice(cs, a, dt, size, rep, pre, hasOpt, comment, o, rc)
      case None =>
        dt match {
          case _: UserType => genRepeatCursor(cs, a, dt, rep, pre, hasOpt, comment, o, rc)
          case _: BytesType | _: StrType => genRepeatCursor(cs, a, dt, rep, pre, hasOpt, comment, o, rc)
          case other => throw new AdaUnsupported(s"repetition of $other")
        }
    }
  }

  private def genRepeatSlice(cs: ClassSpec, a: AttrSpec, dt: DataType, size: Int, rep: RepeatSpec, pre: String, hasOpt: Option[String], comment: List[String], o: Out, rc: RC): Unit = {
    val nm = plain(idRaw(a.id))
    val bs = base(idRaw(a.id))
    val base0 = dt match { case EnumType(_, _, b) => b; case x => x }
    base0 match {
      case _: BitsType | _: BitsType1 => throw new AdaUnsupported("repetition of bit fields")
      case _ =>
    }
    o.comps += s"$nm : ${KT}Slice;"
    if (!rep.isInstanceOf[RepeatUntil] && size > 1) o.valid += s"${KT}Size (This.$nm) mod $size = 0"
    o.belongs += s"${KT}Within (This.$nm, Buffer)"
    accessor(o, s"${bs}_Count", KT + "Length", pre, None, s"${KT}Size (This.$nm) / $size", comment = comment)
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
    val params = s"Buffer : ${KT}Bytes; This : T; Index : ${KT}Length"
    base0 match {
      case Int1Type(sg) =>
        accessor(o, nm, intAda(base0), full, None, if (sg) s"${dec}To_S8 (${raw(1, None)})" else raw(1, None), params)
      case IntMultiType(sg, w, fe) =>
        val r = raw(w.width, fe)
        accessor(o, nm, intAda(base0), full, None, if (sg) s"${dec}To_S${w.width * 8} ($r)" else r, params)
      case FloatMultiType(w, fe) =>
        val r = raw(w.width, fe)
        val bits = floatBits(w)
        val sfx = if (w.width == 4) "F32" else "F64"
        accessor(o, s"${bs}_Bits", bits, full, None, r, params)
        accessor(o, nm, s"Kaitai.Floats.$sfx", s"$full and then Kaitai.Floats.Is_Finite (${bs}_Bits (Buffer, This, Index))", None,
          s"Kaitai.Floats.To_$sfx (${bs}_Bits (Buffer, This, Index))", params)
      case other => throw new AdaUnsupported(s"repetition of $other")
    }
    val target = s"This.$nm"
    val stmts: List[String] = rep match {
      case RepeatExpr(e) =>
        val t = T(e, rc)
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
        val ct = guard(a.path)(tr.translate(cond))
        tr.iterator = None
        val check = guarded(ct.guards, List(s"$done := ${ct.code};"), rc, List(s"$done := True;"))
        List(s"$start := S;", s"$done := False;", s"for I in 1 .. ${KS}Remaining (S) + 1 loop") ++
          ind(readValue(base0, value, rc) ++ List(s"exit when not ${KS}OK (S);") ++ check ++ List(
            s"exit when $done;",
            s"pragma Loop_Invariant (${KS}Is_Valid (S, Buffer) and then ${KS}Advanced ($start, S) and then not $done);"
          )) ++ List(
          "end loop;",
          s"if ${KS}OK (S) and then not $done then",
          "   " + failStmt(rc, "Limit_Exceeded"),
          "end if;",
          s"$target := ${KS}Between ($start, S);"
        )
    }
    o.parse ++= wrapCond(a, hasOpt, stmts, rc)
  }

  private def genRepeatCursor(cs: ClassSpec, a: AttrSpec, dt: DataType, rep: RepeatSpec, pre: String, hasOpt: Option[String], comment: List[String], o: Out, rc: RC): Unit = {
    val nm = plain(idRaw(a.id))
    val bs = base(idRaw(a.id))
    val isSlice = !dt.isInstanceOf[UserType]
    opTypes += "Length"
    val selfElem = dt match { case ut: UserType => ut.classSpec.get eq cs; case _ => false }
    val (elT, elPkg, elBelongs) = dt match {
      case ut: UserType if selfElem => ("T", "", true)
      case ut: UserType => (userPkg(ut) + ".T", userPkg(ut) + ".", hasBelongs(ut.classSpec.get))
      case _ => (KT + "Slice", "", true)
    }
    def valid(x: String) = if (isSlice) s"${KS}OK (S)" else s"${elPkg}Valid ($x)"
    val cur = s"${bs}_Cursor"
    o.comps += s"${bs}_Io : ${KS}Stream;"
    o.comps += s"${bs}_Count : ${KT}Length := 0;"
    o.belongs += s"${KS}Is_Valid (This.${bs}_Io, Buffer)"
    o.privTypes ++= List(s"type $cur is record", s"   Io   : ${KS}Stream;", s"   Left : ${KT}Length := 0;", "end record;", "")
    o.pub ++= ind(comment ++ List(s"--  $nm: not kept, but parsed again when asked for", ""))
    o.pub ++= ind(List(
      s"function ${bs}_Count (This : T) return ${KT}Length", s"with Pre => $pre;", "",
      s"type $cur is private;", "",
      s"function Belongs_To (Position : $cur; Buffer : ${KT}Bytes) return Boolean;", "",
      s"function ${bs}_First (This : T) return $cur", s"with Pre => $pre;", "",
      s"function Remaining (Position : $cur) return ${KT}Length;", "",
      s"function Has_Element (Position : $cur) return Boolean", "is (Remaining (Position) > 0);", "",
      s"procedure Next (Buffer : ${KT}Bytes; This : T; Position : in out $cur; Element : out $elT)",
      "with", "  Pre  => Valid (This) and then Belongs_To (Position, Buffer) and then Has_Element (Position),",
      "  Post =>", "    Belongs_To (Position, Buffer) and then Remaining (Position) < Remaining (Position'Old)" +
        (if (elBelongs) s"\n    and then ${if (isSlice) KT + "Within" else elPkg + "Belongs_To"} (Element, Buffer);" else ";"), "",
      s"procedure Get_$bs (Buffer : ${KT}Bytes; This : T; Index : ${KT}Length; Element : out $elT)",
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
    o.privFuncs += s"is (Io => This.${bs}_Io, Left => This.${bs}_Count);"
    o.privFuncs += ""
    o.privFuncs += s"function Remaining (Position : $cur) return ${KT}Length"
    o.privFuncs += "is (Position.Left);"
    o.privFuncs += ""

    // reading one element
    val elScope = new Scope
    val elRc = RC("S", rc.order, elScope, a.path)
    val elRcOuter = elRc
    // order and arguments inside the helper come from This
    val inHelperRc = RC("S", if (storesOrder(cs)) "This.Order" else "", elScope, a.path)
    tr.iterator = None
    val elemStmts0 = readValue(dt, "Element", inHelperRc, defaultTarget = true)
    val usesThis = elemStmts0.exists(_.contains("This"))
    val elemStmtsText = elemStmts0
    val needsHelper = isSlice || elemStmts0.size != 1 || elScope.decls.nonEmpty
    val helper = s"Parse_${bs}_Element"
    val helperParams = s"Buffer : ${KT}Bytes; S : in out ${KS}Stream; " + (if (usesThis) "This : T; " else "") + s"Element : out $elT"
    val callThis = if (usesThis) "This, " else ""
    val postElem = s"${KS}Is_Valid (S, Buffer) and then ${KS}Advanced (S'Old, S)" + (if (isSlice) "" else s" and then (if ${valid("Element")} then ${KS}OK (S))") +
      (if (elBelongs) s" and then ${if (isSlice) KT + "Within" else elPkg + "Belongs_To"} (Element, Buffer)" else "")
    def elemCall(stream: String): String =
      if (needsHelper) s"$helper (Buffer, $stream, ${callThis}Element);"
      else s"${elemStmts0.head.replace("(Buffer, S,", s"(Buffer, $stream,")}"
    if (needsHelper) {
      o.bodyBefore ++= List(s"--  Parse one element of $nm", s"procedure $helper ($helperParams)", "with", s"  Pre  => ${KS}Is_Valid (S, Buffer),") ++
        (if (selfElem) List(s"  Post => $postElem,", "  Subprogram_Variant => (Decreases => This.Depth, Decreases => 0);", "") else List(s"  Post => $postElem;", ""))
      val declLines = elScope.decls.toList
      val body = elemStmts0
      val unref = if (body.exists(_.contains("Buffer"))) Nil else List("pragma Warnings (Off, Buffer);")
      o.bodyBefore ++= List(s"procedure $helper ($helperParams) is") ++ ind(declLines ++ unref) ++ List("begin") ++ ind(body) ++ List(s"end $helper;", "")
    }
    if (isSlice && elemStmts0.isEmpty) throw new AdaUnsupported("empty element")

    // Next and Get_
    val nextBody = List(
      s"procedure Next (Buffer : ${KT}Bytes; This : T; Position : in out $cur; Element : out $elT) is"
    ) ++ (if (usesThis) Nil else List("   pragma Warnings (Off, This);")) ++ List(
      "begin",
      "   " + elemCall("Position.Io"),
      s"   Position.Left := (if ${valid("Element").replace("OK (S)", "OK (Position.Io)")} then Position.Left - 1 else 0);",
      "end Next;", ""
    )
    val within = if (isSlice) s"${KT}Within (Result, Buffer)" else if (elBelongs) s"${elPkg}Belongs_To (Result, Buffer)" else ""
    val getBody = List(
      s"procedure Get_$bs (Buffer : ${KT}Bytes; This : T; Index : ${KT}Length; Element : out $elT) is",
      s"   Position : $cur := ${bs}_First (This);",
      s"   Result   : $elT;",
      "begin",
      s"   for I in 0 .. Index loop",
      s"      pragma Loop_Invariant (Belongs_To (Position, Buffer)${if (within.nonEmpty) " and then " + within else ""});",
      "      exit when not Has_Element (Position);",
      "      Next (Buffer, This, Position, Result);",
      "   end loop;",
      "   Element := Result;",
      s"end Get_$bs;", ""
    )
    o.bodyAfter ++= nextBody
    o.bodyAfter ++= getBody

    // Parse
    val el = rc.scope.fresh("Element")
    rc.scope.decls += s"$el : $elT;"
    val parseCall = if (needsHelper) {
      if (usesThis) rc.scope.passesThis = true
      s"$helper (Buffer, S, ${callThis}$el);"
    } else elemStmts0.head.replace(" Element);", s" $el);")
    val Iv = "I"
    // a slice has no validity to look at; the loop uses the element in its invariant
    val sliceInv = if (isSlice) s" and then ${KT}Within ($el, Buffer)" else ""
    val loop: List[String] = rep match {
      case RepeatExpr(e) =>
        val t = T(e, rc)
        guarded(t.guards, List(s"This.${bs}_Count := ${countCode(t)};"), rc, Nil) ++ List(
          s"for $Iv in 1 .. This.${bs}_Count loop"
        ) ++ ind(List(parseCall, s"exit when not ${valid(el).replace("OK (S)", "OK (S)")};",
          s"pragma Loop_Invariant (${KS}Is_Valid (S, Buffer) and then ${KS}Advanced (S'Loop_Entry, S)$sliceInv);")) ++ List("end loop;")
      case RepeatEos =>
        List(s"This.${bs}_Count := 0;", s"for $Iv in 1 .. ${KS}Remaining (S) loop") ++
          ind(List(s"exit when ${KS}Is_EOF (S);", parseCall, s"exit when not ${valid(el)};", s"This.${bs}_Count := $Iv;",
            s"pragma Loop_Invariant (${KS}Is_Valid (S, Buffer) and then ${KS}Advanced (S'Loop_Entry, S)$sliceInv);")) ++ List(
          "end loop;", s"if ${KS}OK (S) and then not ${KS}Is_EOF (S) then", "   " + failStmt(rc, "Limit_Exceeded"), "end if;")
      case RepeatUntil(cond) =>
        val done = rc.scope.fresh("Done")
        rc.scope.decls += s"$done : Boolean;"
        tr.buffer = Some("Buffer"); tr.io = Some("S"); tr.thisName = "This"
        tr.iterator = Some((dt, el))
        tr.knownValid = Set(el)
        val ct = guard(a.path)(tr.translate(cond))
        tr.iterator = None
        tr.knownValid = Set()
        val check = guarded(ct.guards, List(s"$done := ${ct.code};"), rc, List(s"$done := True;"))
        List(s"This.${bs}_Count := 0;", s"$done := False;", s"for $Iv in 1 .. ${KS}Remaining (S) + 1 loop") ++
          ind(List(parseCall, s"exit when not ${valid(el)};", s"This.${bs}_Count := $Iv;") ++ check ++ List(
            s"exit when $done;",
            s"pragma Loop_Invariant (${KS}Is_Valid (S, Buffer) and then ${KS}Advanced (S'Loop_Entry, S)$sliceInv and then not $done);")) ++
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
    val t = guard(path)(tr.translate(v.value))
    val ct = v.ifExpr.map(c => guard(path)(tr.translate(c)))
    val (hasGuard, usesBuf) = valueInfo(cs, v)
    val isSlice = v.dataType match { case _: BytesType | _: StrType => true; case _ => false }
    val params = if (usesBuf) s"Buffer : ${KT}Bytes; This : T" else "This : T"
    val args = if (usesBuf) "Buffer, This" else "This"
    val pre0 = if (usesBuf) "Valid (This) and then Belongs_To (This, Buffer)" else "Valid (This)"
    if (usesBuf && !hasBelongs(cs)) throw new AdaUnsupported("value instance that needs the buffer in a type without slices")
    o.pub += s"   --  instance ${v.id.humanReadable}"
    o.pub ++= ind(docLines(v.doc))
    o.pub += ""
    var pre = pre0
    if (hasGuard) {
      val gs = ct.toList.flatMap(c => c.guards ++ List(if (c.prec >= 3) s"(${c.code})" else c.code)) ++ t.guards
      o.pub ++= ind(List(s"function ${hasNm(bs)} ($params) return Boolean", s"with Pre => $pre0;", ""))
      o.privFuncs += s"function ${hasNm(bs)} ($params) return Boolean"
      o.privFuncs += s"is (${if (gs.isEmpty) "True" else gs.distinct.mkString("\n and then ")});"
      o.privFuncs += ""
      pre = s"$pre0 and then ${hasNm(bs)} ($args)"
    }
    v.dataType match {
      case et: EnumType =>
        val ada = KT + "S64"
        accessor(o, s"${bs}_Value", ada, pre, None, t.code, params)
        val spec = et.enumSpec.get
        val tyName = enumTypeName(spec)
        val q = tyName.split('.').dropRight(1).mkString(".") match { case "" => ""; case x => x + "." }
        accessor(o, nm, tyName, s"$pre and then ${q}Is_${enumTy(spec)} (${bs}_Value ($args))", None,
          s"${q}To_${enumTy(spec)} (${bs}_Value ($args))", params)
      case _: IntType =>
        accessor(o, nm, KT + "S64", pre, None, t.code, params)
      case _: BooleanType =>
        accessor(o, nm, "Boolean", pre, None, t.code, params)
      case _: BytesType | _: StrType =>
        t.vt match {
          case VBytes | VStr(_) =>
            accessor(o, nm, KT + "Slice", pre, Some(s"${KT}Within ($nm'Result, Buffer)"), t.code, params)
          case _ => throw new AdaUnsupported("value instance of bytes or string that is not a field")
        }
      case other => throw new AdaUnsupported(s"value instance of type $other")
    }
    tr.buffer = saveBuf
  }

  private def genParseInstance(cs: ClassSpec, p: ParseInstanceSpec, o: Out): Unit = {
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
      val t = T(c, rc.copy(s = "L"))
      // Has_X as a value instance function
      val gs = t.guards ++ List(if (t.prec >= 3) s"(${t.code})" else t.code)
      o.pub ++= ind(List(s"function ${hasNm(bs)} (This : T) return Boolean", "with Pre => Valid (This);", ""))
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
    val spec = s"procedure $nm (Buffer : ${KT}Bytes; This : T; Result : out $resT; Outcome : out ${KT}Status_Kind)"
    o.pub ++= ind(docLines(p.doc))
    o.pub += s"   --  instance ${p.id.humanReadable}: parsed when asked for"
    o.pub += s"   $spec"
    o.pub += s"   with Pre => $pre${post.map(x => s", Post => $x").getOrElse("")};"
    o.pub += ""
    // body
    val posT = T(p.pos.get, rc)
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
    cs.params.foreach { p => pre += s"This.${plain(idRaw(p.id))} := ${paramName(idRaw(p.id))};" }
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
