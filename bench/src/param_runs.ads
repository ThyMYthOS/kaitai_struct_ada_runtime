--  The loops of param_bench: each parses the records of one format with the parser of one variant, one Parse per
--  record, and forms a checksum.  Phase 1 parses the records and takes the number of children; phase 2 also walks
--  the children with the cursor and reads a field of each that needs no value from outside; phase 3 also reads
--  what needs it.  The variants of a format agree on the checksum of each phase.  The cost of a part is the
--  difference between two phases.

with Kaitai.Types; use Kaitai.Types;
with Param_Data;

package Param_Runs is

   --  0 parses nothing, which is the cost that every phase starts with
   subtype Phase_Number is Natural range 0 .. 3;

   type Variant is (Pstr_1, Pstr_2, Pstr_2w, Puser_1, Puser_2, Puser_2w, Puser_3, Pnav_1, Pnav_2, Pnav_3);

   --  The format that a variant parses
   function Format_Of (V : Variant) return Param_Data.Format
   is (case V is
         when Pstr_1 | Pstr_2 | Pstr_2w              => Param_Data.Pstr,
         when Puser_1 | Puser_2 | Puser_2w | Puser_3 => Param_Data.Puser,
         when Pnav_1 | Pnav_2 | Pnav_3               => Param_Data.Pnav);

   --  The name of a variant as the programs take it
   function Name (V : Variant) return String
   is (case V is
         when Pstr_1   => "pstr_v1",
         when Pstr_2   => "pstr_v2",
         when Pstr_2w  => "pstr_v2w",
         when Puser_1  => "puser_v1",
         when Puser_2  => "puser_v2",
         when Puser_2w => "puser_v2w",
         when Puser_3  => "puser_v3",
         when Pnav_1   => "pnav_v1",
         when Pnav_2   => "pnav_v2",
         when Pnav_3   => "pnav_v3");

   --  The checksum of Data, records of Format_Of (V), parsed up to Phase
   function Run (V : Variant; Data : Bytes; Phase : Phase_Number) return U64;

   --  Print the size of the type of the child and of the parent, in bytes, for each variant
   procedure Put_Sizes;

end Param_Runs;
