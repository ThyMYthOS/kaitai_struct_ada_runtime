--  The measurements of instance_bench and of its counterpart for the target: an instance with a position that an
--  expression of `seq` needs, parsed again at every use (D1) or parsed once at the first use and kept (D2).  What
--  each variant does is described in README.md.  The loops that stand for the program that parses the records are
--  here; every record is parsed by one call of Parse, from a stream of its own.

with Kaitai.Types; use Kaitai.Types;

package Inst_Runs
  with SPARK_Mode, Always_Terminates
is

   --  _Parse: the record is parsed and everything it holds in `seq` is read.  _Access: after that the instance is
   --  asked for four times through its accessor.
   type Variant is
     (Int_D1_Parse,
      Int_D1_Access,
      Int_D2_Parse,
      Int_D2_Access,
      User_D1_Parse,
      User_D1_Access,
      User_D2_Parse,
      User_D2_Access,
      Until_D1_Parse,
      Until_D1_Access,
      Until_D2_Parse,
      Until_D2_Access);

   --  The bytes a variant reads: records of 8 chunks and the count, records of 3 numbers, 6 entries and a header, and
   --  records of 6 entries and a header
   type Layout is (Int_L, User_L, Until_L);

   function Layout_Of (V : Variant) return Layout
   is (case V is
         when Int_D1_Parse | Int_D1_Access | Int_D2_Parse | Int_D2_Access         => Int_L,
         when User_D1_Parse | User_D1_Access | User_D2_Parse | User_D2_Access     => User_L,
         when Until_D1_Parse | Until_D1_Access | Until_D2_Parse | Until_D2_Access => Until_L);

   --  The variants that give the same checksum for the same input
   type Group is (Int_Parse_G, Int_Access_G, User_Parse_G, User_Access_G, Until_Parse_G, Until_Access_G);

   function Group_Of (V : Variant) return Group
   is (case V is
         when Int_D1_Parse | Int_D2_Parse       => Int_Parse_G,
         when Int_D1_Access | Int_D2_Access     => Int_Access_G,
         when User_D1_Parse | User_D2_Parse     => User_Parse_G,
         when User_D1_Access | User_D2_Access   => User_Access_G,
         when Until_D1_Parse | Until_D2_Parse   => Until_Parse_G,
         when Until_D1_Access | Until_D2_Access => Until_Access_G);

   --  Size in bytes of a record
   function Record_Size (L : Layout) return Length
   is (case L is
         when Int_L   => 68,
         when User_L  => 21,
         when Until_L => 18);

   --  Parses every complete record of Data as the variant says and returns the checksum
   function Run (V : Variant; Data : Bytes) return U64;

end Inst_Runs;
