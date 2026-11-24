with Kaitai.Decoding;

use Kaitai;

package body Sample_Parser
  with SPARK_Mode
is

   procedure Parse (Buffer : Bytes; S : in out Stream; Result : out Message) is
      Magic : U16;
   begin
      Read_U2be (Buffer, S, Magic);
      Read_U1 (Buffer, S, Result.Version);
      Read_U1 (Buffer, S, Result.Flags);
      Read_U4le (Buffer, S, Result.Size);
      Read_S8be (Buffer, S, Result.Id);
      if OK (S) and then Magic /= Magic_Value then
         Fail (S, Validation_Not_Equal);
      end if;
      Read_Bytes (S, To_Length (U64 (Result.Size)), Result.Payload);
   end Parse;

   procedure Parse_Block (Buffer : Bytes; S : in out Stream; Result : out Message) is
      From : Length;
   begin
      Result := (others => <>);
      if OK (S) and then Remaining (S) >= Header_Size then
         From := Next_Index (S);
         Result.Version := Decoding.U8_At (Buffer, From + 2);
         Result.Flags := Decoding.U8_At (Buffer, From + 3);
         Result.Size := Decoding.U32_LE (Buffer, From + 4);
         Result.Id := Decoding.To_S64 (Decoding.U64_BE (Buffer, From + 8));
         if Decoding.U16_BE (Buffer, From) = Magic_Value then
            Advance (S, Header_Size);
         else
            Fail (S, Validation_Not_Equal);
         end if;
      else
         Skip (S, Header_Size);
      end if;
      Read_Bytes (S, To_Length (U64 (Result.Size)), Result.Payload);
   end Parse_Block;

end Sample_Parser;
