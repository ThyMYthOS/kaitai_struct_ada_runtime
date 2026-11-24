package body Kaitai.Encoding
  with SPARK_Mode
is

   function To_U64 (Value : S64) return U64 is
   begin
      if Value >= 0 then
         pragma Assert (U64 (Value) < 2**63);
         pragma Assert (Decoding.To_S64 (U64 (Value)) = Value);
         return U64 (Value);
      end if;
      declare
         Low : constant U64 := U64 (Value - S64'First);
      begin
         pragma Assert (Low < 2**63);
         pragma Assert (S64 (Low) = Value - S64'First);
         pragma Assert (Low + 2**63 >= 2**63);
         pragma Assert (Low + 2**63 - 2**63 = Low);
         pragma Assert (S64 (Low + 2**63 - 2**63) = Value - S64'First);
         pragma Assert (S64 (Low + 2**63 - 2**63) + S64'First = Value);
         pragma Assert (Low + 2**63 >= 2**63);
         pragma Assert (Decoding.To_S64 (Low + 2**63) = Value);
         return Low + 2**63;
      end;
   end To_U64;

   procedure Put_U8 (Target : in out Bytes; From : Index; Value : U8) is
   begin
      Target (From) := Value;
   end Put_U8;

   procedure Put_U16_LE (Target : in out Bytes; From : Index; Value : U16) is
   begin
      Target (From) := U8 (Value and 16#FF#);
      Target (From + 1) := U8 (Shift_Right (Value, 8));
   end Put_U16_LE;

   procedure Put_U16_BE (Target : in out Bytes; From : Index; Value : U16) is
   begin
      Target (From) := U8 (Shift_Right (Value, 8));
      Target (From + 1) := U8 (Value and 16#FF#);
   end Put_U16_BE;

   procedure Put_U32_LE (Target : in out Bytes; From : Index; Value : U32) is
   begin
      Target (From) := U8 (Value and 16#FF#);
      Target (From + 1) := U8 (Shift_Right (Value, 8) and 16#FF#);
      Target (From + 2) := U8 (Shift_Right (Value, 16) and 16#FF#);
      Target (From + 3) := U8 (Shift_Right (Value, 24));
   end Put_U32_LE;

   procedure Put_U32_BE (Target : in out Bytes; From : Index; Value : U32) is
   begin
      Target (From) := U8 (Shift_Right (Value, 24));
      Target (From + 1) := U8 (Shift_Right (Value, 16) and 16#FF#);
      Target (From + 2) := U8 (Shift_Right (Value, 8) and 16#FF#);
      Target (From + 3) := U8 (Value and 16#FF#);
   end Put_U32_BE;

   procedure Put_U64_LE (Target : in out Bytes; From : Index; Value : U64) is
   begin
      Put_U32_LE (Target, From, U32 (Value and 16#FFFF_FFFF#));
      Put_U32_LE (Target, From + 4, U32 (Shift_Right (Value, 32)));
   end Put_U64_LE;

   procedure Put_U64_BE (Target : in out Bytes; From : Index; Value : U64) is
   begin
      Put_U32_BE (Target, From, U32 (Shift_Right (Value, 32)));
      Put_U32_BE (Target, From + 4, U32 (Value and 16#FFFF_FFFF#));
   end Put_U64_BE;

end Kaitai.Encoding;
