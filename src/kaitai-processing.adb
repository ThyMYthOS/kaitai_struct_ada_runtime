package body Kaitai.Processing
  with SPARK_Mode
is

   procedure Xor_One (Source : Bytes; Key : Byte; Target : out Bytes) is
   begin
      for I in Target'Range loop
         Target (I) := Source (Source'First + (I - Target'First)) xor Key;
         pragma Loop_Invariant (for all J in Target'First .. I => Target (J)'Initialized);
         pragma
           Loop_Invariant
             (for all J in Target'First .. I => Target (J) = (Source (Source'First + (J - Target'First)) xor Key));
      end loop;
   end Xor_One;

   --  The remainder of N + 1 follows from the remainder of N without a
   --  division.  The provers find this only when it is all they are asked.
   procedure Lemma_Next_Remainder (N : Length; L : Length)
   with
     Ghost,
     Pre  => L > 0 and then N < Length'Last,
     Post => (N + 1) mod L = (if N mod L = L - 1 then 0 else N mod L + 1);

   procedure Lemma_Next_Remainder (N : Length; L : Length) is null;

   procedure Xor_Many (Source : Bytes; Key : Bytes; Target : out Bytes) is
      --  Index of the byte of Key for the current byte.  Counting it along
      --  avoids a division for every byte.
      K : Index := Key'First;
   begin
      for I in Target'Range loop
         Target (I) := Source (Source'First + (I - Target'First)) xor Key (K);
         pragma Loop_Invariant (K = Key'First + (I - Target'First) mod Key'Length);
         pragma Loop_Invariant (for all J in Target'First .. I => Target (J)'Initialized);
         pragma
           Loop_Invariant
             (for all J in Target'First .. I =>
                Target (J)
                = (Source (Source'First + (J - Target'First)) xor Key (Key'First + (J - Target'First) mod Key'Length)));
         Lemma_Next_Remainder (I - Target'First, Key'Length);
         K := (if K = Key'Last then Key'First else K + 1);
      end loop;
   end Xor_Many;

   procedure Rotate_Left (Source : Bytes; Amount : Integer; Target : out Bytes) is
      Bits : constant Natural := Amount mod 8;
   begin
      for I in Target'Range loop
         Target (I) := Rotate_Left (Source (Source'First + (I - Target'First)), Bits);
         pragma Loop_Invariant (for all J in Target'First .. I => Target (J)'Initialized);
         pragma
           Loop_Invariant
             (for all J in Target'First .. I =>
                Target (J) = Rotate_Left (Source (Source'First + (J - Target'First)), Bits));
      end loop;
   end Rotate_Left;

end Kaitai.Processing;
