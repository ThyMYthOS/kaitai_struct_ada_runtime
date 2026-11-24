with Ada.Text_IO;

package body Bench_Support is

   function Seed (Value : U64) return Random_State
   is (Random_State (if Value = 0 then 16#9E37_79B9_7F4A_7C15# else Value));

   procedure Next (State : in out Random_State; Value : out U64) is
      X : U64 := U64 (State);
   begin
      X := X xor Shift_Left (X, 13);
      X := X xor Shift_Right (X, 7);
      X := X xor Shift_Left (X, 17);
      State := Random_State (X);
      Value := X;
   end Next;

   function Generate_TLV (Records : Positive; Max_Payload : Natural) return Bytes_Access is
      State  : Random_State := Seed (42);
      Value  : U64;
      Total  : Length := 0;
      Result : Bytes_Access;
      Pos    : Length := 1;
   begin
      --  First pass: size
      for I in 1 .. Records loop
         Next (State, Value);
         Total := Total + 3 + Length (Value mod U64 (Max_Payload + 1));
      end loop;

      Result := new Bytes (1 .. Total);
      State := Seed (42);

      for I in 1 .. Records loop
         Next (State, Value);
         declare
            Len : constant Length := Length (Value mod U64 (Max_Payload + 1));
         begin
            Result (Pos) := U8 (Shift_Right (Value, 32) and 16#FF#);
            Result (Pos + 1) := U8 (U64 (Len) and 16#FF#);
            Result (Pos + 2) := U8 (Shift_Right (U64 (Len), 8) and 16#FF#);
            for J in 1 .. Len loop
               Result (Pos + 2 + J) := U8 ((Value + U64 (J)) and 16#FF#);
            end loop;
            Pos := Pos + 3 + Len;
         end;
      end loop;
      return Result;
   end Generate_TLV;

   function Generate_Fixed (Records : Positive) return Bytes_Access is
      State  : Random_State := Seed (7);
      Value  : U64;
      Result : constant Bytes_Access := new Bytes (1 .. Length (Records) * 15);
   begin
      for I in Result'Range loop
         if (I - 1) mod 8 = 0 then
            Next (State, Value);
         end if;
         Result (I) := U8 (Shift_Right (Value, Natural (((I - 1) mod 8) * 8)) and 16#FF#);
      end loop;
      return Result;
   end Generate_Fixed;

   function RSS_KiB return Natural is
      use Ada.Text_IO;
      File : File_Type;
   begin
      Open (File, In_File, "/proc/self/status");
      while not End_Of_File (File) loop
         declare
            Line : constant String := Get_Line (File);
         begin
            if Line'Length > 6 and then Line (Line'First .. Line'First + 5) = "VmRSS:" then
               Close (File);
               declare
                  Result : Natural := 0;
               begin
                  for C of Line loop
                     if C in '0' .. '9' then
                        Result := Result * 10 + (Character'Pos (C) - Character'Pos ('0'));
                     end if;
                  end loop;
                  return Result;
               end;
            end if;
         end;
      end loop;
      Close (File);
      return 0;
   exception
      when others =>
         return 0;
   end RSS_KiB;

   function Start return Stopwatch
   is (Stopwatch (Ada.Real_Time.Clock));

   function Elapsed_NS (Watch : Stopwatch) return Long_Float is
      use Ada.Real_Time;
   begin
      return Long_Float (To_Duration (Clock - Time (Watch))) * 1.0E9;
   end Elapsed_NS;

   function Minimum (Values : Samples) return Long_Float is
      Result : Long_Float := Values (Values'First);
   begin
      for V of Values loop
         Result := Long_Float'Min (Result, V);
      end loop;
      return Result;
   end Minimum;

   function Median (Values : Samples) return Long_Float is
      Sorted : Samples := Values;
      Tmp    : Long_Float;
   begin
      for I in Sorted'First + 1 .. Sorted'Last loop
         for J in reverse Sorted'First + 1 .. I loop
            exit when Sorted (J - 1) <= Sorted (J);
            Tmp := Sorted (J);
            Sorted (J) := Sorted (J - 1);
            Sorted (J - 1) := Tmp;
         end loop;
      end loop;
      return Sorted ((Sorted'First + Sorted'Last) / 2);
   end Median;

end Bench_Support;
