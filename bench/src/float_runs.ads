--  The loops of the floating point benchmark.  Each parses records of
--
--     x : f8le,  y : f4le,  n : u2le,  k : u1
--
--  and computes expressions from x and y, which are finite and of moderate
--  size, as the preparation of the data makes them.  The parser of one
--  record is not inlined and gets the stream as a parameter, as generated
--  code would.  A variant that asks first does it as generated code does,
--  with the functions of Kaitai.Float_Arithmetic; the plain variants use
--  the operators of Ada.  The variants of one operation must agree on the
--  checksum.

with Kaitai.Types; use Kaitai.Types;

package Float_Runs is

   --  Give x and y of every record an exponent between 2**(-20) and 2**19
   procedure Prepare (Data : in out Bytes);

   --  The parse of a record, its two floats converted and mixed into the checksum, nothing else
   function Run_Nop (Data : Bytes) return U64
   with No_Inline;

   --  x + y with the operator of Ada, y an f4 converted to F64
   function Run_Add_Plain (Data : Bytes) return U64
   with No_Inline;

   --  x + y, asked with Add_OK first
   function Run_Add_Guarded (Data : Bytes) return U64
   with No_Inline;

   --  x + 0.05 with the operator of Ada
   function Run_Add_Lit_Plain (Data : Bytes) return U64
   with No_Inline;

   --  x + 0.05, asked with Add_OK first
   function Run_Add_Lit_Guarded (Data : Bytes) return U64
   with No_Inline;

   --  x - y with the operator of Ada
   function Run_Sub_Plain (Data : Bytes) return U64
   with No_Inline;

   --  x - y, asked with Subtract_OK first
   function Run_Sub_Guarded (Data : Bytes) return U64
   with No_Inline;

   --  x * y with the operator of Ada
   function Run_Mul_Plain (Data : Bytes) return U64
   with No_Inline;

   --  x * y, asked with Multiply_OK first
   function Run_Mul_Guarded (Data : Bytes) return U64
   with No_Inline;

   --  to_i of x, written by hand with Floor and Ceiling
   function Run_To_I_Plain (Data : Bytes) return U64
   with No_Inline;

   --  to_i of x, Truncate asked with Truncate_OK first
   function Run_To_I_Guarded (Data : Bytes) return U64
   with No_Inline;

   --  four expressions of one record with the operators of Ada
   function Run_Expr_Plain (Data : Bytes) return U64
   with No_Inline;

   --  the same four, every operation asked first
   function Run_Expr_Guarded (Data : Bytes) return U64
   with No_Inline;

   --  the same four, with no question where the types answer it
   function Run_Expr_Guarded_Where_Needed (Data : Bytes) return U64
   with No_Inline;

end Float_Runs;
