--  Chooses the generator of Rep_Data that a variant of Rep_Runs reads its input from.

with Kaitai.Types; use Kaitai.Types;
with Rep_Data;
with Rep_Runs;

package Rep_Setup is

   use type Rep_Runs.Layout;

   --  The input of Layout for N elements; the buffer has Rep_Data.Max_Size (N) bytes, 8 for Rep_Empty_L
   procedure Generate (L : Rep_Runs.Layout; N : Natural; Buffer : out Bytes; Used : out Length)
   with
     Pre =>
       Buffer'First = 1
       and then Buffer'Length >= (if L = Rep_Runs.Rep_Empty_L then 8 else Rep_Data.Max_Size (N))
       and then N > 0;

end Rep_Setup;
