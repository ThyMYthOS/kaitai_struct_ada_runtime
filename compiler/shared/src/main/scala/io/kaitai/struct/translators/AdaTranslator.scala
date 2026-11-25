package io.kaitai.struct.translators

import io.kaitai.struct.ClassTypeProvider
import io.kaitai.struct.datatype.{BigEndian, DataType, LittleEndian}
import io.kaitai.struct.datatype.DataType._
import io.kaitai.struct.exprlang.Ast
import io.kaitai.struct.format._

/**
  * Raised for everything the Ada backend cannot express. The class compiler
  * adds the path of the attribute and turns it into a compilation error.
  */
class AdaUnsupported(msg: String) extends RuntimeException(msg)

/** The Kaitai type of a translated expression, as far as the Ada backend tells types apart. */
sealed trait VT
case object VInt extends VT
case object VBool extends VT
case class VEnum(spec: EnumSpec) extends VT
/** A slice of the buffer */
case object VBytes extends VT
case class VBytesLit(bytes: Seq[Int]) extends VT
case class VStr(encoding: String) extends VT
case class VStrLit(s: String) extends VT
case class VUser(cs: ClassSpec) extends VT
/** The number of elements of a repetition; `code` of the translation is that number as S64 */
case object VArray extends VT
case object VStream extends VT
/** `_root._io` */
case object VRootStream extends VT

/**
  * Result of the translation of an expression: Ada code, the conditions
  * under which it is defined in evaluation order, and what is known about
  * its value.
  *
  * `prec` is 0 for an atom, 1 for an additive expression, 2 for a
  * relation, 3 for `and then`/`or else`, 4 for something that needs
  * parentheses in any context.
  */
case class ATr(
  code: String,
  prec: Int,
  guards: List[String],
  vt: VT,
  lo: BigInt = AdaTranslator.S64Min,
  hi: BigInt = AdaTranslator.S64Max,
  /** the value as stored, without conversion to S64: code and Ada type */
  native: Option[(String, String)] = None,
  usesBuffer: Boolean = false,
  /** the value is the result of an unconverted use of a component of the current type */
  isLiteral: Boolean = false
) {
  def atom: String = if (prec == 0) code else s"($code)"
}

/** What the translator needs to know from the class compiler. */
trait AdaTranslatorEnv {
  /** Ada name of a field, instance or parameter */
  def memberName(cs: ClassSpec, id: Identifier): String
  /** The name of a member without the suffix that avoids reserved words; derived names are built from it */
  def memberBase(id: Identifier): String
  /** Name of the function that tells whether an optional member exists */
  def presenceName(cs: ClassSpec, id: Identifier): String
  /** Ada name of the package of a type, as written from inside the package tree */
  def packageOf(cs: ClassSpec): String
  /** True if the value instance has a function `Has_X`, that is, is not always defined */
  def valueInstanceHasGuard(cs: ClassSpec, inst: ValueInstanceSpec): Boolean
  /** Ada name of the type of the enumeration */
  def enumTypeName(spec: EnumSpec): String
  /** The encoding of a string, as the Ada library names it */
  def encodingName(enc: String, path: List[String]): String
  /** True if the value instance function needs the buffer as a parameter */
  def valueInstanceUsesBuffer(cs: ClassSpec, inst: ValueInstanceSpec): Boolean
  /** True if the field is stored in the record (it is not a `contents` field) */
  def isStored(attr: AttrLikeSpec): Boolean
  /**
    * What `e` stands for in class `cs` if it is a reference to the parent or the root: the name of
    * the component of the record that holds the value and its type (`Left`), or an expression of
    * `cs` itself that means the same (`Right`).
    */
  def outsideRef(cs: ClassSpec, e: Ast.expr): Option[Either[(String, DataType), Ast.expr]]
}

object AdaTranslator {
  /** Encodings with characters of several bytes for which the library has no decoder */
  val MultiByte: Set[String] = Set("SHIFT_JIS", "BIG5", "EUC-KR", "EUC-JP", "GBK", "GB2312", "GB18030")

  /** Encodings in which equal strings are equal bytes also across the two */
  val AsciiOrUtf8: Set[String] = Set("ASCII", "US-ASCII", "UTF-8")

  val S64Min: BigInt = -(BigInt(1) << 63)
  val S64Max: BigInt = (BigInt(1) << 63) - 1
  val Half: (BigInt, BigInt) = (-(BigInt(1) << 31), (BigInt(1) << 31) - 1)

  /** Size in bytes of an element that a repetition keeps as one slice */
  def fixedElement(dt: DataType): Option[Int] = dt match {
    case Int1Type(_) => Some(1)
    case IntMultiType(_, w, _) => Some(w.width)
    case FloatMultiType(w, _) => Some(w.width)
    case EnumType(_, _, b) => fixedElement(b)
    case _ => None
  }
  /** Aggregate of bytes, as the translator writes a literal array */
  def aggregate(bytes: Seq[Int]): String =
    if (bytes.isEmpty) "(1 .. 0 => 0)"
    else if (bytes.size == 1) f"(1 => 16#${bytes.head}%02X#)"
    else bytes.map(b => f"16#$b%02X#").mkString("(", ", ", ")")

  /** The field is kept as the bytes of the input, because it has `process` */
  def hasProcess(dt: DataType): Boolean = dt match {
    case b: BytesType => b.process.isDefined
    case StrFromBytesType(b, _, _) => b.process.isDefined
    case ut: UserTypeFromBytes => ut.process.isDefined
    case _ => false
  }
  def repeatKind(dt: DataType): String = if (fixedElement(dt).isDefined) "slice" else "cursor"
  def elementSize(dt: DataType): Int = fixedElement(dt).get

  def inS64(lo: BigInt, hi: BigInt): Boolean = lo >= S64Min && hi <= S64Max
  def clip(lo: BigInt, hi: BigInt): (BigInt, BigInt) = (lo.max(S64Min), hi.min(S64Max))
  def inHalf(t: ATr): Boolean = t.lo >= Half._1 && t.hi <= Half._2

  /** Ada type and range of an integer data type */
  def intInfo(dt: DataType): Option[(String, BigInt, BigInt)] = dt match {
    case Int1Type(false) => Some(("U8", 0, 255))
    case Int1Type(true) => Some(("S8", -128, 127))
    case IntMultiType(signed, w, _) =>
      val bits = w.width * 8
      if (signed)
        Some((s"S$bits", -(BigInt(1) << (bits - 1)), (BigInt(1) << (bits - 1)) - 1))
      else
        Some((s"U$bits", BigInt(0), (BigInt(1) << bits) - 1))
    case BitsType(w, _) => Some(("U64", BigInt(0), (BigInt(1) << w) - 1))
    case _ => None
  }
}

/**
  * Translates expressions to Ada. Integer expressions are computed in S64;
  * each use of an operation that can fail adds a condition to `guards`.
  */
class AdaTranslator(val provider: ClassTypeProvider, val env: AdaTranslatorEnv) {
  import AdaTranslator._

  private val typeDetector = new TypeDetector(provider)

  /** Name of the buffer, if there is one in the context */
  var buffer: Option[String] = Some("Buffer")
  /** Name of the stream, if there is one in the context */
  var io: Option[String] = None
  /** Codes of values of a user type that are known to be valid */
  var knownValid: Set[String] = Set()
  /** What `_` stands for: Kaitai type and code of the value as stored */
  var iterator: Option[(DataType, String)] = None
  /** Value instances being inlined, to find cycles */
  private var inlining: List[String] = Nil
  /** Code that stands for the current record */
  var thisName: String = "This"
  /** Types of the library whose operators the generated code uses */
  val ops = scala.collection.mutable.Set[String]()

  private def unsupported(msg: String): Nothing = throw new AdaUnsupported(msg)

  private def useBuffer(): String = buffer match {
    case Some(b) => b
    case None => unsupported("the expression needs the input buffer, which is not available in a value instance function")
  }

  def conj(gs: List[String]): String = gs.mkString(" and then ")

  def dedupe(gs: List[String]): List[String] = gs.distinct

  private def wrapOp(t: ATr, maxPrec: Int): String =
    if (t.prec <= maxPrec) t.code else s"(${t.code})"

  private def int(code: String, prec: Int, guards: List[String], lo: BigInt, hi: BigInt, ub: Boolean = false, native: Option[(String, String)] = None): ATr = {
    val (l, h) = clip(lo, hi)
    ATr(code, prec, dedupe(guards), VInt, l, h, native, ub)
  }

  def translate(e: Ast.expr): ATr = e match {
    case _: Ast.expr.Name | _: Ast.expr.Attribute if env.outsideRef(provider.nowClass, e).isDefined =>
      env.outsideRef(provider.nowClass, e).get match {
        case Left((comp, dt)) => fromValue(dt, s"$thisName.$comp", Nil)
        case Right(own) => translate(own)
      }
    case Ast.expr.IntNum(n) =>
      if (n < S64Min || n > S64Max)
        unsupported(s"integer literal $n does not fit into 64 bits")
      ATr(n.toString, if (n < 0) 1 else 0, Nil, VInt, n, n, isLiteral = true)
    case Ast.expr.Bool(b) =>
      ATr(if (b) "True" else "False", 0, Nil, VBool, isLiteral = true)
    case Ast.expr.Str(s) =>
      ATr(s, 0, Nil, VStrLit(s), isLiteral = true)
    case Ast.expr.FloatNum(_) =>
      unsupported("floating-point arithmetic")
    case Ast.expr.InterpolatedStr(_) =>
      unsupported("string interpolation")
    case Ast.expr.List(elts) =>
      val bytes = elts.map {
        case Ast.expr.IntNum(n) if n >= 0 && n <= 255 => n.toInt
        case _ => unsupported("array literal that is not a list of bytes")
      }
      ATr(aggregate(bytes), 0, Nil, VBytesLit(bytes), isLiteral = true)
    case Ast.expr.EnumByLabel(enumName, label, inType) =>
      val spec = provider.resolveEnum(inType, enumName.name)
      val value = spec.map.collectFirst { case (id, v) if v.name == label.name => id }.getOrElse(
        unsupported(s"unknown enum member ${enumName.name}::${label.name}")
      )
      if (value < S64Min || value > S64Max)
        unsupported(s"enum value $value does not fit into 64 bits")
      ATr(value.toString, if (value < 0) 1 else 0, Nil, VEnum(spec), value, value, isLiteral = true)
    case Ast.expr.EnumById(enumName, id, inType) =>
      val spec = provider.resolveEnum(inType, enumName.name)
      val t = translate(id)
      t.vt match {
        case VInt | VEnum(_) => t.copy(vt = VEnum(spec))
        case _ => unsupported("enum value computed from something that is not an integer")
      }
    case Ast.expr.Name(id) => translateName(id.name)
    case Ast.expr.InternalName(id) => unsupported(s"internal name ${id.humanReadable}")
    case Ast.expr.UnaryOp(op, v) => translateUnary(op, translate(v))
    case Ast.expr.BinOp(l, op, r) => translateBin(op, translate(l), translate(r))
    case Ast.expr.Compare(l, op, r) => translateCompare(op, translate(l), translate(r))
    case Ast.expr.BoolOp(op, values) => translateBoolOp(op, values.map(translate))
    case Ast.expr.IfExp(c, a, b) => translateIf(translate(c), translate(a), translate(b))
    case Ast.expr.Attribute(value, attr) => translateAttribute(value, attr.name)
    case Ast.expr.Call(func, args) => translateCall(func, args)
    case Ast.expr.Subscript(a, b) => translateSubscript(a, b)
    case Ast.expr.CastToType(_, _) => unsupported("cast (`.as<...>`)")
    case Ast.expr.ByteSizeOfType(t) => sizeOf(t, 8)
    case Ast.expr.BitSizeOfType(t) => sizeOf(t, 1)
  }


  /** `a[b]`: a byte of bytes, or an element of a repetition of integers of a fixed size */
  private def translateSubscript(a: Ast.expr, b: Ast.expr): ATr = {
    val cs = provider.nowClass
    a match {
      case Ast.expr.Name(id) if isRepeatedMember(cs, id.name) =>
        val i = translate(b)
        requireInt(i)
        val m = provider.resolveMember(cs, id.name) match {
          case at: AttrSpec => at
          case _ => unsupported(s"subscript of the repeated member `${id.name}`")
        }
        if (hasProcess(m.dataType)) unsupported(s"field `${id.name}` has `process`; its value exists only when it is asked for")
        m.cond.repeat match {
          case RepeatUntil(_) => unsupported("subscript of a repetition until a condition")
          case _ =>
        }
        val base = m.dataType match {
          case EnumType(_, _, bb) => bb
          case other => other
        }
        base match {
          case _: FloatMultiType | _: BitsType | _: BitsType1 => unsupported("subscript of a repetition of floats or of bit fields")
          case _ =>
        }
        val size = fixedElement(m.dataType).getOrElse(unsupported(s"subscript of the repeated member `${id.name}`"))
        val comp = env.memberName(cs, m.id)
        val has = if (m.cond.ifExpr.isDefined) List(s"$thisName.${env.presenceName(cs, m.id)}") else Nil
        ops += "Length"
        val count = s"Kaitai.Types.S64 (Kaitai.Types.Size ($thisName.$comp) / $size)"
        val guards = i.guards ++ has ++ (if (i.lo >= 0) Nil else List(s"${i.atom} >= 0")) ++ List(s"${i.atom} < $count")
        val at = s"$thisName.$comp.First + Kaitai.Types.Length (${i.code}) * $size"
        val dec = "Kaitai.Decoding."
        val decoded = base match {
          case Int1Type(sg) =>
            val r = s"${dec}U8_At (${useBuffer()}, $at)"
            if (sg) s"${dec}To_S8 ($r)" else r
          case IntMultiType(sg, w, fe) =>
            val bits = w.width * 8
            val le = s"${dec}U${bits}_LE (${useBuffer()}, $at)"
            val be = s"${dec}U${bits}_BE (${useBuffer()}, $at)"
            val r = fe match {
              case Some(LittleEndian) => le
              case Some(BigEndian) => be
              case _ => ops += "Byte_Order"; s"(if $thisName.Order = Kaitai.Types.Little_Endian then $le else $be)"
            }
            if (sg) s"${dec}To_S$bits ($r)" else r
          case other => unsupported(s"subscript of a repetition of $other")
        }
        fromValue(m.dataType, decoded, guards).copy(usesBuffer = true)
      case _ =>
        val v = translate(a)
        val i = translate(b)
        requireInt(i)
        v.vt match {
          case VBytesLit(bytes) =>
            if (!i.isLiteral || i.lo < 0 || i.lo >= bytes.size) unsupported("subscript of an array literal that is not a literal inside it")
            val n = BigInt(bytes(i.lo.toInt))
            ATr(n.toString, 0, Nil, VInt, n, n, isLiteral = true)
          case VBytes =>
            val bf = useBuffer()
            ops += "Length"
            val guards = v.guards ++ i.guards ++ (if (i.lo >= 0) Nil else List(s"${i.atom} >= 0")) ++
              List(s"${i.atom} < Kaitai.Types.S64 (Kaitai.Types.Size (${v.code}))")
            int(s"Kaitai.Types.S64 ($bf (${v.atom}.First + Kaitai.Types.Length (${i.code})))", 0, guards, 0, 255, ub = true)
          case _ => unsupported("subscript of something that is not bytes or a repetition of integers")
        }
    }
  }

  private def sizeOf(t: Ast.typeId, factor: Int): ATr = {
    // the size in bits; the sizes of the compiler front end are in bits
    val bits: Option[BigInt] =
      if (!t.absolute && t.names.size == 1) {
        DataType.pureFromString(Some(t.names.head)) match {
          case Int1Type(_) => Some(8)
          case IntMultiType(_, w, _) => Some(w.width * 8)
          case FloatMultiType(w, _) => Some(w.width * 8)
          case _: UserType =>
            userSize(t)
          case _ => None
        }
      } else userSize(t)
    bits match {
      case Some(b) =>
        // a size in bytes counts a begun byte as a whole one
        val n = if (factor == 8) (b + 7) / 8 else b
        ATr(n.toString, 0, Nil, VInt, n, n, isLiteral = true)
      case None => unsupported(s"size of type ${t.nameAsStr}")
    }
  }

  private def userSize(t: Ast.typeId): Option[BigInt] =
    try {
      provider.resolveClassSpec(t).seqSize match {
        case FixedSized(n) => Some(n)
        case _ => None
      }
    } catch { case _: Throwable => None }

  // ---------------------------------------------------------------- names

  private def translateName(name: String): ATr = name match {
    case Identifier.ROOT => unsupported("`_root` (only `_root._io` is supported)")
    case Identifier.PARENT => unsupported("`_parent` (what a type needs from its parent has to be passed as a parameter)")
    case Identifier.IO =>
      ATr(io.getOrElse(unsupported("`_io` in a value instance")), 0, Nil, VStream)
    case Identifier.ITERATOR =>
      iterator match {
        case Some((dt, code)) => fromValue(dt, code, Nil)
        case None => unsupported("`_` outside of `repeat-until` and `valid`")
      }
    case Identifier.INDEX => unsupported("`_index`")
    case Identifier.SIZEOF =>
      // `_sizeof` alone is the size of the current type, known at compile time
      val n = BigInt(CommonSizeOf.getByteSizeOfClassSpec(provider.nowClass))
      ATr(n.toString, 0, Nil, VInt, n, n, isLiteral = true)
    case _ =>
      val cs = provider.nowClass
      val member = provider.resolveMember(cs, name)
      member match {
        case p: ParamDefSpec =>
          fromValue(p.dataType, s"$thisName.${env.memberName(cs, p.id)}", Nil)
        case a: AttrSpec =>
          if (!env.isStored(a))
            unsupported(s"field `$name` holds `contents`, which is checked but not stored")
          if (hasProcess(a.dataType))
            unsupported(s"field `$name` has `process`; its value exists only when it is asked for")
          val has = if (a.cond.ifExpr.isDefined) List(s"$thisName.${env.presenceName(provider.nowClass, a.id)}") else Nil
          a.cond.repeat match {
            case NoRepeat => fromValue(a.dataType, s"$thisName.${env.memberName(cs, a.id)}", has)
            case _ => unsupported(s"repeated field `$name` (only `.size` is supported)")
          }
        case v: ValueInstanceSpec =>
          inlineInstance(cs, v)
        case _: ParseInstanceSpec =>
          unsupported(s"parse instance `$name` used in an expression")
      }
  }

  /** The expression of a value instance of the current type, inlined. */
  private def inlineInstance(cs: ClassSpec, v: ValueInstanceSpec): ATr = {
    val key = cs.nameAsStr + "::" + v.id.name
    if (inlining.contains(key))
      unsupported(s"value instance `${v.id.name}` depends on itself")
    inlining = key :: inlining
    try {
      val t = translate(v.value)
      v.ifExpr match {
        case Some(c) =>
          // an instance with a condition is only defined where the condition holds
          val ct = translate(c)
          val cc = if (ct.prec >= 3) s"(${ct.code})" else ct.code
          t.copy(guards = dedupe(ct.guards ++ List(cc) ++ t.guards))
        case None => t
      }
    } finally {
      inlining = inlining.tail
    }
  }

  /**
    * The translation of a value of the given Kaitai type that is available
    * as Ada expression `code` of the type it was read as.
    */
  def fromValue(dt: DataType, code: String, guards: List[String]): ATr = dt match {
    case _: IntType | _: EnumType =>
      val base = dt match {
        case EnumType(_, _, b) => b
        case other => other
      }
      val (adaType, lo, hi) = base match {
        case CalcIntType => ("S64", S64Min, S64Max)
        case _ => intInfo(base).getOrElse(unsupported(s"integer type $base"))
      }
      val vt: VT = dt match {
        case et: EnumType => VEnum(et.enumSpec.get)
        case _ => VInt
      }
      if (adaType == "U64") {
        ATr(s"Kaitai.Types.S64 ($code)", 0, dedupe(guards ++ List(s"Kaitai.Arithmetic.Fits ($code)")), vt, lo, hi.min(S64Max), Some((code, adaType)))
      } else if (adaType == "S64") {
        ATr(code, 0, dedupe(guards), vt, lo, hi, Some((code, adaType)))
      } else {
        ATr(s"Kaitai.Types.S64 ($code)", 0, dedupe(guards), vt, lo, hi, Some((code, adaType)))
      }
    case _: BooleanType =>
      ATr(code, 0, dedupe(guards), VBool, native = Some((code, "Boolean")))
    case _: FloatType => unsupported("floating-point arithmetic")
    case _: BytesType =>
      ATr(code, 0, dedupe(guards), VBytes, native = Some((code, "Slice")))
    case StrFromBytesType(_, enc, _) =>
      ATr(code, 0, dedupe(guards), VStr(enc), native = Some((code, "Slice")))
    case _: StrType => unsupported("string computed by an expression")
    case ut: UserType =>
      ATr(code, 0, dedupe(guards), VUser(ut.classSpec.get))
    case _: SwitchType => unsupported("field whose type depends on a value, used in an expression")
    case _: ArrayType => unsupported("array in an expression (only `.size` is supported)")
    case other => unsupported(s"value of type $other")
  }

  // ------------------------------------------------------------ attributes

  private def isRootIo(e: Ast.expr): Boolean = e match {
    case Ast.expr.Attribute(Ast.expr.Name(Ast.identifier(Identifier.ROOT)), Ast.identifier(Identifier.IO)) => true
    case _ => false
  }

  private def translateAttribute(value: Ast.expr, attr: String): ATr = {
    if (attr == Identifier.SIZEOF) {
      // `x._sizeof` is a constant of the compiler, like `sizeof<type>`
      val n = BigInt(CommonSizeOf.bitToByteSize(CommonSizeOf.getBitsSizeOfType(value.toString, typeDetector.detectType(value))))
      return ATr(n.toString, 0, Nil, VInt, n, n, isLiteral = true)
    }
    if (isRootIo(value)) {
      return attr match {
        case "size" => int(s"Kaitai.Types.S64 (${useBuffer()}'Length)", 0, Nil, 0, S64Max, ub = true)
        case _ => unsupported(s"`_root._io.$attr`")
      }
    }
    // a repetition of the current type: only its size
    value match {
      case Ast.expr.Name(id) if attr == "size" && isRepeatedMember(provider.nowClass, id.name) =>
        return arraySize(provider.nowClass, id.name, thisName, Nil)
      case _ =>
    }
    val v = value match {
      case Ast.expr.Name(id) if isRepeatedMember(provider.nowClass, id.name) =>
        unsupported(s"repeated field `${id.name}` (only `.size` is supported)")
      case _ => translate(value)
    }
    v.vt match {
      case VStream =>
        val s = v.code
        attr match {
          case "size" => int(s"Kaitai.Types.S64 (Kaitai.Streams.Size ($s))", 0, Nil, 0, S64Max)
          case "pos" => int(s"Kaitai.Types.S64 (Kaitai.Streams.Pos ($s))", 0, Nil, 0, S64Max)
          case "eof" => ATr(s"Kaitai.Streams.Is_EOF ($s)", 0, Nil, VBool)
          case _ => unsupported(s"`_io.$attr`")
        }
      case VUser(cs) => memberOf(v, cs, attr)
      case VBytes | VBytesLit(_) =>
        val b = useBuffer()
        v.vt match {
          case VBytesLit(bytes) =>
            attr match {
              case "length" | "size" => ATr(bytes.size.toString, 0, Nil, VInt, bytes.size, bytes.size, isLiteral = true)
              case _ => unsupported(s"`.$attr` of an array literal")
            }
          case _ =>
            attr match {
              case "length" | "size" => int(s"Kaitai.Types.S64 (Kaitai.Types.Size (${v.code}))", 0, v.guards, 0, S64Max, ub = true)
              case "min" => int(s"Kaitai.Types.S64 (Kaitai.Byte_Arrays.Min ($b, ${v.code}))", 0, v.guards, 0, 255, ub = true)
              case "max" => int(s"Kaitai.Types.S64 (Kaitai.Byte_Arrays.Max ($b, ${v.code}))", 0, v.guards, 0, 255, ub = true)
              case "first" =>
                int(s"Kaitai.Types.S64 ($b (${v.atom}.First))", 0, v.guards ++ List(s"not Kaitai.Types.Is_Empty (${v.code})"), 0, 255, ub = true)
              case "last" =>
                int(s"Kaitai.Types.S64 ($b (${v.atom}.Last))", 0, v.guards ++ List(s"not Kaitai.Types.Is_Empty (${v.code})"), 0, 255, ub = true)
              case _ => unsupported(s"`.$attr` of bytes")
            }
        }
      case VStr(enc) =>
        val b = useBuffer()
        attr match {
          case "length" =>
            if (AdaTranslator.MultiByte.contains(enc.toUpperCase))
              unsupported(s"`.length` of a string in $enc, whose characters the library cannot count")
            val e = env.encodingName(enc, Nil)
            if (e == "Single_Byte" || e == "US_ASCII")
              int(s"Kaitai.Types.S64 (Kaitai.Types.Size (${v.code}))", 0, v.guards, 0, S64Max, ub = true)
            else
              int(s"Kaitai.Types.S64 (Kaitai.Strings.Character_Count ($b, ${v.code}, $e))", 0, v.guards, 0, S64Max, ub = true)
          case "to_i" =>
            byteWise(enc, "`.to_i`")
            toInteger(v, ATr("10", 0, Nil, VInt, 10, 10, isLiteral = true))
          case _ => unsupported(s"`.$attr` of a string")
        }
      case VStrLit(s) =>
        attr match {
          case "length" =>
            val n = codePoints(s).size
            ATr(n.toString, 0, Nil, VInt, n, n, isLiteral = true)
          case _ => unsupported(s"`.$attr` of a string literal")
        }
      case VInt | VEnum(_) =>
        attr match {
          case "to_i" => v
          case _ => unsupported(s"`.$attr` of an integer")
        }
      case VBool =>
        attr match {
          case "to_i" => int(s"(if ${v.code} then 1 else 0)", 0, v.guards, 0, 1)
          case _ => unsupported(s"`.$attr` of a boolean")
        }
      case other => unsupported(s"`.$attr` of $other")
    }
  }

  private def isRepeatedMember(cs: ClassSpec, name: String): Boolean =
    try {
      provider.resolveMember(cs, name) match {
        case a: AttrLikeSpec => a.cond.repeat != NoRepeat
        case _ => false
      }
    } catch { case _: Throwable => false }

  /** Number of elements of repeated member `name` of `cs`, whose record is `obj`. */
  private def arraySize(cs: ClassSpec, name: String, obj: String, g: List[String]): ATr = {
    val a = provider.resolveMember(cs, name).asInstanceOf[AttrLikeSpec]
    val comp = env.memberName(cs, a.id)
    val bs = env.memberBase(a.id)
    val has = if (a.cond.ifExpr.isDefined) List(s"$obj.${env.presenceName(cs, a.id)}") else Nil
    val code = AdaTranslator.repeatKind(a.dataType) match {
      case "slice" =>
        ops += "Length"
        s"Kaitai.Types.S64 (Kaitai.Types.Size ($obj.$comp) / ${AdaTranslator.elementSize(a.dataType)})"
      case _ => s"Kaitai.Types.S64 ($obj.${bs}_Count)"
    }
    int(code, 0, g ++ has, 0, S64Max)
  }

  private def toInteger(v: ATr, base: ATr): ATr = {
    val b = useBuffer()
    int(
      s"Kaitai.Strings.To_Integer ($b, ${v.code}, ${base.code})",
      0,
      v.guards ++ base.guards ++ List(s"Kaitai.Strings.To_Integer_OK ($b, ${v.code}, ${base.code})"),
      S64Min, S64Max, ub = true
    )
  }

  private def translateCall(func: Ast.expr, args: Seq[Ast.expr]): ATr = func match {
    case Ast.expr.Attribute(obj, Ast.identifier("to_i")) if args.size == 1 =>
      val v = translate(obj)
      v.vt match {
        case VStr(enc) =>
          byteWise(enc, "`.to_i`")
          toInteger(v, translate(args.head))
        case _ => unsupported("`to_i` with an argument on something but a string")
      }
    case Ast.expr.Attribute(_, Ast.identifier(m)) => unsupported(s"method `$m`")
    case _ => unsupported("call")
  }

  /** Attribute `attr` of the value `obj`, a user type `cs`. */
  private def memberOf(obj: ATr, cs: ClassSpec, attr: String): ATr = {
    if (attr == Identifier.PARENT || attr == Identifier.ROOT)
      unsupported(s"`$attr`")
    if (attr == Identifier.IO)
      unsupported("`_io` of a nested value")
    val member = provider.resolveMember(cs, attr)
    val pkg = env.packageOf(cs)
    val validGuard = if (knownValid.contains(obj.code)) Nil else List(s"$pkg.Valid (${obj.code})")
    val g0 = obj.guards ++ validGuard
    val nm = env.memberName(cs, member.id)
    val bs = env.memberBase(member.id)
    member match {
      case p: ParamDefSpec =>
        fromAccessor(p.dataType, pkg, nm, bs, obj.code, g0)
      case a: AttrSpec =>
        if (!env.isStored(a))
          unsupported(s"field `$attr` holds `contents`, which is checked but not stored")
        if (hasProcess(a.dataType))
          unsupported(s"field `$attr` has `process`; its value exists only when it is asked for")
        val has = if (a.cond.ifExpr.isDefined) List(s"$pkg.${env.presenceName(cs, member.id)} (${obj.code})") else Nil
        a.cond.repeat match {
          case NoRepeat => fromAccessor(a.dataType, pkg, nm, bs, obj.code, g0 ++ has)
          case _ => unsupported(s"repeated field `$attr` of a nested value")
        }
      case v: ValueInstanceSpec =>
        if (env.valueInstanceUsesBuffer(cs, v))
          unsupported(s"instance `$attr` of a nested value needs the buffer")
        val has = if (env.valueInstanceHasGuard(cs, v)) List(s"$pkg.${env.presenceName(cs, member.id)} (${obj.code})") else Nil
        val g = g0 ++ has
        v.dataType match {
          case _: IntType =>
            int(s"$pkg.$nm (${obj.code})", 0, g, S64Min, S64Max)
          case _: BooleanType =>
            ATr(s"$pkg.$nm (${obj.code})", 0, dedupe(g), VBool)
          case et: EnumType =>
            ATr(s"$pkg.${bs}_Value (${obj.code})", 0, dedupe(g), VEnum(et.enumSpec.get))
          case _ => unsupported(s"instance `$attr` of a nested value that is not an integer, a boolean or an enumeration")
        }
      case _: ParseInstanceSpec =>
        unsupported(s"parse instance `$attr` of a nested value")
    }
  }

  private def fromAccessor(dt: DataType, pkg: String, nm: String, bs: String, obj: String, g: List[String]): ATr = dt match {
    case _: SwitchType => unsupported(s"field `$nm` whose type depends on a value")
    case _: EnumType => fromValue(dt, s"$pkg.${bs}_Value ($obj)", g)
    case _: FloatType => unsupported("floating-point arithmetic")
    case _ => fromValue(dt, s"$pkg.$nm ($obj)", g)
  }

  // ------------------------------------------------------------- operators

  private def translateUnary(op: Ast.unaryop, v: ATr): ATr = op match {
    case Ast.unaryop.Not =>
      if (v.vt != VBool) unsupported("`not` of a value that is not a boolean")
      ATr(s"not ${v.atom}", 2, v.guards, VBool)
    case Ast.unaryop.Minus =>
      requireInt(v)
      ops += "S64"
      val guard = if (v.lo > S64Min) Nil else List(s"Kaitai.Arithmetic.Negate_OK (${v.code})")
      int(s"-${v.atom}", 1, v.guards ++ guard, -v.hi, -v.lo, v.usesBuffer)
    case Ast.unaryop.Invert =>
      requireInt(v)
      int(s"Kaitai.Arithmetic.Bit_Xor (${v.code}, -1)", 0, v.guards, -v.hi - 1, -v.lo - 1, v.usesBuffer)
  }

  private def requireInt(v: ATr): Unit = v.vt match {
    case VInt | VEnum(_) =>
    case _ => unsupported("arithmetic on something that is not an integer")
  }

  private def translateBin(op: Ast.operator, l: ATr, r: ATr): ATr = {
    (l.vt, r.vt) match {
      case (VStr(_) | VStrLit(_), _) | (_, VStr(_) | VStrLit(_)) =>
        unsupported("string concatenation")
      case _ =>
    }
    requireInt(l)
    requireInt(r)
    val g = l.guards ++ r.guards
    val ub = l.usesBuffer || r.usesBuffer
    if (l.isLiteral && r.isLiteral) {
      val folded: Option[BigInt] = op match {
        case Ast.operator.Add => Some(l.lo + r.lo)
        case Ast.operator.Sub => Some(l.lo - r.lo)
        case Ast.operator.Mult => Some(l.lo * r.lo)
        case _ => None
      }
      folded.filter(v => v >= S64Min && v <= S64Max).foreach { v =>
        return ATr(v.toString, if (v < 0) 1 else 0, Nil, VInt, v, v, isLiteral = true)
      }
    }
    op match {
      case Ast.operator.Add =>
        ops += "S64"
        val (lo, hi) = (l.lo + r.lo, l.hi + r.hi)
        if (inS64(lo, hi))
          int(s"${wrapOp(l, 1)} + ${wrapOp(r, 0)}", 1, g, lo, hi, ub)
        else
          int(s"${wrapOp(l, 1)} + ${wrapOp(r, 0)}", 1, g ++ List(s"Kaitai.Arithmetic.Add_OK (${l.code}, ${r.code})"), lo, hi, ub)
      case Ast.operator.Sub =>
        ops += "S64"
        val (lo, hi) = (l.lo - r.hi, l.hi - r.lo)
        if (inS64(lo, hi))
          int(s"${wrapOp(l, 1)} - ${wrapOp(r, 0)}", 1, g, lo, hi, ub)
        else
          int(s"${wrapOp(l, 1)} - ${wrapOp(r, 0)}", 1, g ++ List(s"Kaitai.Arithmetic.Subtract_OK (${l.code}, ${r.code})"), lo, hi, ub)
      case Ast.operator.Mult =>
        val corners = List(l.lo * r.lo, l.lo * r.hi, l.hi * r.lo, l.hi * r.hi)
        val guard = if (inHalf(l) && inHalf(r)) Nil else List(s"Kaitai.Arithmetic.Multiply_OK (${l.code}, ${r.code})")
        int(s"Kaitai.Arithmetic.Multiply (${l.code}, ${r.code})", 0, g ++ guard, corners.min, corners.max, ub)
      case Ast.operator.Div =>
        val excludesZero = r.lo > 0 || r.hi < 0
        val safe = excludesZero && (r.lo > -1 || r.hi < -1 || l.lo > S64Min)
        val guard = if (safe) Nil else List(s"Kaitai.Arithmetic.Divide_OK (${l.code}, ${r.code})")
        val (lo, hi) =
          if (r.lo > 0) {
            val cs = List(l.lo / r.lo, l.lo / r.hi, l.hi / r.lo, l.hi / r.hi)
            (cs.min, cs.max)
          } else (S64Min, S64Max)
        int(s"Kaitai.Arithmetic.Divide (${l.code}, ${r.code})", 0, g ++ guard, lo, hi, ub)
      case Ast.operator.Mod =>
        val guard = if (r.lo > 0) Nil else List(s"Kaitai.Arithmetic.Modulo_OK (${r.code})")
        val hi = if (r.lo > 0) r.hi - 1 else S64Max
        int(s"Kaitai.Arithmetic.Modulo (${l.code}, ${r.code})", 0, g ++ guard, 0, hi, ub)
      case Ast.operator.LShift =>
        val guard = if (r.lo >= 0 && r.hi <= 63) Nil else List(s"Kaitai.Arithmetic.Shift_OK (${r.code})")
        val (lo, hi) =
          if (l.lo >= 0 && r.lo >= 0 && r.hi <= 63 && l.hi << r.hi.toInt <= S64Max) (BigInt(0), l.hi << r.hi.toInt)
          else (S64Min, S64Max)
        int(s"Kaitai.Arithmetic.Bit_Shift_Left (${l.code}, ${r.code})", 0, g ++ guard, lo, hi, ub)
      case Ast.operator.RShift =>
        val guard = if (r.lo >= 0 && r.hi <= 63) Nil else List(s"Kaitai.Arithmetic.Shift_OK (${r.code})")
        val (lo, hi) = if (l.lo >= 0) (BigInt(0), l.hi) else (S64Min, S64Max)
        int(s"Kaitai.Arithmetic.Bit_Shift_Right (${l.code}, ${r.code})", 0, g ++ guard, lo, hi, ub)
      case Ast.operator.BitAnd =>
        val (lo, hi) =
          if (l.lo >= 0 && r.lo >= 0) (BigInt(0), l.hi.min(r.hi))
          else if (r.lo >= 0) (BigInt(0), r.hi)
          else if (l.lo >= 0) (BigInt(0), l.hi)
          else (S64Min, S64Max)
        int(s"Kaitai.Arithmetic.Bit_And (${l.code}, ${r.code})", 0, g, lo, hi, ub)
      case Ast.operator.BitOr | Ast.operator.BitXor =>
        val name = if (op == Ast.operator.BitOr) "Kaitai.Arithmetic.Bit_Or" else "Kaitai.Arithmetic.Bit_Xor"
        val (lo, hi) =
          if (l.lo >= 0 && r.lo >= 0) {
            val bits = l.hi.max(r.hi).bitLength
            (BigInt(0), (BigInt(1) << bits) - 1)
          } else (S64Min, S64Max)
        int(s"$name (${l.code}, ${r.code})", 0, g, lo, hi, ub)
    }
  }

  private def bytesCode(t: ATr): String = t.vt match {
    case VBytesLit(_) => t.code
    case _ =>
      val b = useBuffer()
      s"$b (${t.atom}.First .. ${t.atom}.Last)"
  }

  private def translateCompare(op: Ast.cmpop, l: ATr, r: ATr): ATr = {
    val g = l.guards ++ r.guards
    val ub = l.usesBuffer || r.usesBuffer
    val opStr = op match {
      case Ast.cmpop.Eq => "="
      case Ast.cmpop.NotEq => "/="
      case Ast.cmpop.Lt => "<"
      case Ast.cmpop.LtE => "<="
      case Ast.cmpop.Gt => ">"
      case Ast.cmpop.GtE => ">="
    }
    def isEq = op == Ast.cmpop.Eq || op == Ast.cmpop.NotEq
    def negate(code: String) = if (op == Ast.cmpop.NotEq) s"not $code" else code
    (l.vt, r.vt) match {
      case ((VInt | VEnum(_)), (VInt | VEnum(_))) if l.isLiteral && r.isLiteral =>
        val c = l.lo.compare(r.lo)
        val res = op match {
          case Ast.cmpop.Eq => c == 0
          case Ast.cmpop.NotEq => c != 0
          case Ast.cmpop.Lt => c < 0
          case Ast.cmpop.LtE => c <= 0
          case Ast.cmpop.Gt => c > 0
          case Ast.cmpop.GtE => c >= 0
        }
        ATr(if (res) "True" else "False", 0, Nil, VBool, isLiteral = true)
      case ((VInt | VEnum(_)), (VInt | VEnum(_))) =>
        ops += "S64"
        ATr(s"${wrapOp(l, 1)} $opStr ${wrapOp(r, 1)}", 2, dedupe(g), VBool, usesBuffer = ub)
      case (VBool, VBool) =>
        ATr(s"${wrapOp(l, 1)} $opStr ${wrapOp(r, 1)}", 2, dedupe(g), VBool, usesBuffer = ub)
      case (VStr(enc), VStrLit(s)) if isEq =>
        ATr(negate(strLiteral(l, s, enc)), 2, dedupe(g), VBool, usesBuffer = true)
      case (VStrLit(s), VStr(enc)) if isEq =>
        ATr(negate(strLiteral(r, s, enc)), 2, dedupe(g), VBool, usesBuffer = true)
      case (VStr(e1), VStr(e2)) if isEq =>
        // equal strings in the same encoding are equal bytes, since the parser has checked that they are valid
        if (e1.toUpperCase != e2.toUpperCase && !(AdaTranslator.AsciiOrUtf8.contains(e1.toUpperCase) && AdaTranslator.AsciiOrUtf8.contains(e2.toUpperCase)))
          unsupported(s"comparison of a string in $e1 with a string in $e2")
        val b = useBuffer()
        ATr(negate(s"Kaitai.Byte_Arrays.Equal ($b, ${l.code}, ${bytesCode(r)})"), 2, dedupe(g), VBool, usesBuffer = true)
      case (VStrLit(a), VStrLit(b)) if isEq =>
        ATr(if ((a == b) == (op == Ast.cmpop.Eq)) "True" else "False", 0, Nil, VBool, isLiteral = true)
      case ((VBytes | VBytesLit(_)), (VBytes | VBytesLit(_))) =>
        val b = useBuffer()
        if (isEq) {
          (l.vt, r.vt) match {
            case (VBytesLit(_), VBytesLit(_)) => unsupported("comparison of two array literals")
            case (VBytesLit(_), _) =>
              ATr(negate(s"Kaitai.Byte_Arrays.Equal ($b, ${r.code}, ${l.code})"), 2, dedupe(g), VBool, usesBuffer = true)
            case _ =>
              ATr(negate(s"Kaitai.Byte_Arrays.Equal ($b, ${l.code}, ${bytesCode(r)})"), 2, dedupe(g), VBool, usesBuffer = true)
          }
        } else {
          ops += "Byte_Arrays.Order"
          val order = op match {
            case Ast.cmpop.Lt => "= Kaitai.Byte_Arrays.Less"
            case Ast.cmpop.LtE => "/= Kaitai.Byte_Arrays.Greater"
            case Ast.cmpop.Gt => "= Kaitai.Byte_Arrays.Greater"
            case _ => "/= Kaitai.Byte_Arrays.Less"
          }
          ATr(s"Kaitai.Byte_Arrays.Compare (${bytesCode(l)}, ${bytesCode(r)}) $order", 2, dedupe(g), VBool, usesBuffer = true)
        }
      case (a, bb) => unsupported(s"comparison of $a with $bb")
    }
  }

  /**
    * Strings are compared, and their digits are read, byte by byte. That is the comparison of the characters only
    * where a character of the literal is one byte, which it is not in UTF-16.
    */
  private def byteWise(enc: String, what: String): Unit =
    if (enc.toUpperCase.startsWith("UTF-16")) unsupported(s"$what of a string in $enc")

  /**
    * The comparison of the string `s` in encoding `enc` with the literal `lit`. A literal of printable ASCII in an
    * encoding of one byte per character is compared with `Equal_Literal`. Any other is encoded here into the bytes
    * of the encoding of the string and compared as bytes, which is the comparison of the characters because the
    * parser has checked that the string is valid, and each string has only one encoding.
    */
  private def strLiteral(s: ATr, lit: String, enc: String): String = {
    val b = useBuffer()
    val e = enc.toUpperCase
    val utf16 = e == "UTF-16LE" || e == "UTF-16BE"
    if (!utf16 && lit.forall(c => c >= 32 && c <= 126))
      s"Kaitai.Strings.Equal_Literal ($b, ${s.code}, \"${lit.replace("\"", "\"\"")}\")"
    else
      s"Kaitai.Byte_Arrays.Equal ($b, ${s.code}, ${aggregate(encodeLiteral(lit, enc))})"
  }

  /** The characters of a string as Unicode code points; a surrogate that is not half of a pair is no text. */
  private def codePoints(lit: String): List[Int] = {
    val out = scala.collection.mutable.ListBuffer[Int]()
    var i = 0
    while (i < lit.length) {
      val c = lit.charAt(i)
      if (Character.isHighSurrogate(c) && i + 1 < lit.length && Character.isLowSurrogate(lit.charAt(i + 1))) {
        out += 0x10000 + ((c - 0xD800) << 10) + (lit.charAt(i + 1) - 0xDC00)
        i += 2
      } else if (Character.isSurrogate(c)) {
        unsupported("string literal that is not valid Unicode text (a lone surrogate)")
      } else {
        out += c.toInt
        i += 1
      }
    }
    out.toList
  }

  /**
    * The bytes of `lit` in the encoding `enc`, for the encodings that can be encoded here without a table: ASCII,
    * UTF-8, ISO-8859-1, UTF-16LE and UTF-16BE. A character that the encoding cannot represent is an error: the
    * string would be different from any string in that encoding. In any other encoding only ASCII characters are
    * encoded, as the one byte they are in every encoding that is based on ASCII.
    */
  def encodeLiteral(lit: String, enc: String): List[Int] = {
    val cps = codePoints(lit)
    def cannot(): Nothing = unsupported(s"string literal with a character that a string in $enc cannot hold or that the Ada backend cannot encode in it (it encodes ASCII, UTF-8, ISO-8859-1, UTF-16LE and UTF-16BE, and for other encodings only ASCII characters)")
    enc.toUpperCase match {
      case "ASCII" | "US-ASCII" =>
        cps.map(c => if (c < 128) c else cannot())
      case "ISO-8859-1" | "ISO8859-1" | "LATIN1" | "ISO_8859-1" =>
        cps.map(c => if (c < 256) c else cannot())
      case "UTF-8" =>
        cps.flatMap { c =>
          if (c < 0x80) List(c)
          else if (c < 0x800) List(0xC0 | (c >> 6), 0x80 | (c & 0x3F))
          else if (c < 0x10000) List(0xE0 | (c >> 12), 0x80 | ((c >> 6) & 0x3F), 0x80 | (c & 0x3F))
          else List(0xF0 | (c >> 18), 0x80 | ((c >> 12) & 0x3F), 0x80 | ((c >> 6) & 0x3F), 0x80 | (c & 0x3F))
        }
      case u @ ("UTF-16LE" | "UTF-16BE") =>
        val units = cps.flatMap { c =>
          if (c < 0x10000) List(c)
          else { val v = c - 0x10000; List(0xD800 + (v >> 10), 0xDC00 + (v & 0x3FF)) }
        }
        units.flatMap(w => if (u == "UTF-16LE") List(w & 0xFF, w >> 8) else List(w >> 8, w & 0xFF))
      case _ =>
        cps.map(c => if (c < 128) c else cannot())
    }
  }

  private def translateBoolOp(op: Ast.boolop, values: Seq[ATr]): ATr = {
    values.foreach(v => if (v.vt != VBool) unsupported("`and`/`or` of something that is not a boolean"))
    val (kw, name) = op match {
      case Ast.boolop.And => ("and then", "and")
      case Ast.boolop.Or => ("or else", "or")
    }
    // the guards of later operands apply only if the earlier ones did not decide
    var guards = List[String]()
    var seen = List[ATr]()
    values.foreach { v =>
      if (seen.isEmpty) {
        guards = guards ++ v.guards
      } else if (v.guards.nonEmpty) {
        val prefix = seen.map(_.code)
        val cond0 = if (prefix.size == 1) wrapOp(seen.head, 2) else prefix.map(c => s"($c)").mkString(s" $kw ")
        val cond = if (op == Ast.boolop.And) cond0 else s"not (${cond0})"
        guards = guards ++ List(s"(if $cond then ${conj(v.guards)})")
      }
      seen = seen :+ v
    }
    val code = values.map(v => if (v.prec >= 3) s"(${v.code})" else v.code).mkString(s" $kw ")
    ATr(code, 3, dedupe(guards), VBool, usesBuffer = values.exists(_.usesBuffer))
  }

  private def translateIf(c: ATr, a: ATr, b: ATr): ATr = {
    if (c.vt != VBool) unsupported("conditional on something that is not a boolean")
    // a condition that is a literal chooses the branch
    val simple = (a.vt, b.vt) match { case ((VInt | VEnum(_) | VBool), (VInt | VEnum(_) | VBool)) => true; case _ => false }
    if (c.isLiteral && simple)
      return (if (c.code == "True") a else b)
    val ga = conj(a.guards)
    val gb = conj(b.guards)
    val cond = c.code
    val cg = (a.guards.isEmpty, b.guards.isEmpty) match {
      case (true, true) => Nil
      case (false, true) => List(s"(if $cond then $ga)")
      case (true, false) => List(s"(if not ${c.atom} then $gb)")
      case (false, false) => List(s"(if $cond then $ga else $gb)")
    }
    val guards = dedupe(c.guards ++ cg)
    val ub = c.usesBuffer || a.usesBuffer || b.usesBuffer
    (a.vt, b.vt) match {
      case ((VInt | VEnum(_)), (VInt | VEnum(_))) =>
        val vt = (a.vt, b.vt) match {
          case (VEnum(s), VEnum(_)) => VEnum(s)
          case _ => VInt
        }
        ATr(s"(if $cond then ${a.code} else ${b.code})", 0, guards, vt, a.lo.min(b.lo), a.hi.max(b.hi), usesBuffer = ub)
      case (VBool, VBool) =>
        ATr(s"(if $cond then ${a.code} else ${b.code})", 0, guards, VBool, usesBuffer = ub)
      case _ => unsupported("conditional expression that is not an integer or a boolean")
    }
  }
}

