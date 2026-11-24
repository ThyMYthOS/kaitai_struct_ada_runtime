package body Showcase
  with SPARK_Mode
is

   Magic : constant Bytes := (16#53#, 16#48#);

   package body Header_Type is

      procedure Parse (Buffer : Bytes; S : in out Stream; This : out T) is
      begin
         Read_U1 (Buffer, S, This.Version);
         Read_U1 (Buffer, S, This.Flags);
         Read_U1 (Buffer, S, This.Len_Name);
         if Subtract_OK (S64 (This.Len_Name), 3) then
            Read_Bytes (S, To_Size (S64 (This.Len_Name) - 3), This.Name);
         else
            Fail (S, Arithmetic_Error);
            This.Name := (First => 1, Last => 0);
         end if;
         This.Is_Valid := OK (S);
      end Parse;

   end Header_Type;

   package body Entry_Type is

      package body Point_Type is

         procedure Parse (Buffer : Bytes; S : in out Stream; This : out T) is
         begin
            Read_S2le (Buffer, S, This.X);
            Read_S2le (Buffer, S, This.Y);
            This.Is_Valid := OK (S);
         end Parse;

      end Point_Type;

      package body Text_Type is

         procedure Parse (Buffer : Bytes; S : in out Stream; This : out T) is
         begin
            Read_Bytes_Term
              (Buffer, S, Term => 0, Include => False, Consume => True, EOS_Error => True, Data => This.Value);
            This.Is_Valid := OK (S);
         end Parse;

      end Text_Type;

      procedure Parse (Buffer : Bytes; S : in out Stream; Flags : U8; This : out T) is
      begin
         This.Flags := Flags;
         Read_U1 (Buffer, S, This.Code);
         case This.Code is
            when 1      =>
               declare
                  Value : Point_Type.T;
               begin
                  Point_Type.Parse (Buffer, S, Value);
                  This.Body_F := (Kind => Body_Is_Point, Point => Value);
               end;

            when 2      =>
               declare
                  Value : Text_Type.T;
               begin
                  Text_Type.Parse (Buffer, S, Value);
                  This.Body_F := (Kind => Body_Is_Text, Text => Value);
               end;

            when others =>
               This.Body_F := (Kind => Body_Is_None);
         end case;
         if Bit_And (S64 (This.Flags), 1) /= 0 then
            This.Has_Extra := True;
            Read_U1 (Buffer, S, This.Extra);
         else
            This.Has_Extra := False;
            This.Extra := 0;
         end if;
         This.Is_Valid := OK (S);
      end Parse;

   end Entry_Type;

   package body Log_Type is

      procedure Parse (Buffer : Bytes; S : in out Stream; This : out T) is
         Element : Entry_Type.Point_Type.T;
      begin
         This.Records_Io := S;
         This.Records_Count := 0;
         for I in 1 .. Remaining (S) loop
            exit when Is_EOF (S);
            Entry_Type.Point_Type.Parse (Buffer, S, Element);
            exit when not Entry_Type.Point_Type.Valid (Element);
            This.Records_Count := I;
            pragma Loop_Invariant (Is_Valid (S, Buffer) and then Advanced (S'Loop_Entry, S));
         end loop;
         if OK (S) and then not Is_EOF (S) then
            Fail (S, Limit_Exceeded);
         end if;
         This.Is_Valid := OK (S);
      end Parse;

      procedure Next (Buffer : Bytes; This : T; Position : in out Records_Cursor; Element : out Entry_Type.Point_Type.T)
      is
         pragma Unreferenced (This);
      begin
         Entry_Type.Point_Type.Parse (Buffer, Position.Io, Element);
         Position.Left := (if Entry_Type.Point_Type.Valid (Element) then Position.Left - 1 else 0);
      end Next;

      procedure Get_Records (Buffer : Bytes; This : T; Index : Length; Element : out Entry_Type.Point_Type.T) is
         Position : Records_Cursor := Records_First (This);
         Result   : Entry_Type.Point_Type.T;
      begin
         for I in 0 .. Index loop
            pragma Loop_Invariant (Belongs_To (Position, Buffer));
            exit when not Has_Element (Position);
            Next (Buffer, This, Position, Result);
         end loop;
         Element := Result;
      end Get_Records;

   end Log_Type;

   --  Parse one element of entries
   procedure Parse_Entries_Element (Buffer : Bytes; S : in out Stream; This : T; Element : out Entry_Type.T)
   with
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Is_Valid (S, Buffer)
       and then Advanced (S'Old, S)
       and then (if Entry_Type.Valid (Element) then OK (S))
       and then Entry_Type.Belongs_To (Element, Buffer);

   procedure Parse_Entries_Element (Buffer : Bytes; S : in out Stream; This : T; Element : out Entry_Type.T) is
      Flags : U8;
   begin
      if Header_Type.Valid (This.Header) then
         Flags := Header_Type.Flags (This.Header);
      else
         Fail (S, Arithmetic_Error);
         Flags := 0;
      end if;
      Entry_Type.Parse (Buffer, S, Flags, Element);
   end Parse_Entries_Element;

   procedure Parse (Buffer : Bytes; S : in out Stream; Scale : U16; This : out T) is
      Sub       : Stream;
      Element   : Entry_Type.T;
      Element_2 : Entry_Type.Point_Type.T;
      Done      : Boolean;
   begin
      This := (others => <>);
      This.Io := S;
      This.Scale := Scale;
      Read_Contents (Buffer, S, Magic);
      Read_U1 (Buffer, S, This.Kind);
      Read_U2le (Buffer, S, This.Num_Entries);
      Header_Type.Parse (Buffer, S, This.Header);

      This.Entries_Io := S;
      This.Entries_Count := To_Count (S64 (This.Num_Entries));
      for I in 1 .. This.Entries_Count loop
         Parse_Entries_Element (Buffer, S, This, Element);
         exit when not Entry_Type.Valid (Element);
         pragma Loop_Invariant (Is_Valid (S, Buffer) and then Advanced (S'Loop_Entry, S));
      end loop;

      if S64 (This.Kind) = 2 then
         This.Has_Tail_Len := True;
         Read_U4le (Buffer, S, This.Tail_Len);
      end if;

      This.Points_Io := S;
      This.Points_Count := 0;
      Done := False;
      for I in 1 .. Remaining (S) + 1 loop
         Entry_Type.Point_Type.Parse (Buffer, S, Element_2);
         exit when not Entry_Type.Point_Type.Valid (Element_2);
         This.Points_Count := I;
         Done := S64 (Entry_Type.Point_Type.X (Element_2)) = 0;
         exit when Done;
         pragma Loop_Invariant (Is_Valid (S, Buffer) and then Advanced (S'Loop_Entry, S) and then not Done);
      end loop;
      if OK (S) and then not Done then
         Fail (S, Limit_Exceeded);
      end if;

      Read_U1 (Buffer, S, This.Len_Log);
      Substream (Buffer, S, To_Size (S64 (This.Len_Log)), Sub);
      Log_Type.Parse (Buffer, Sub, This.Log);
      Join (S, Sub);

      Read_Elements_Full (S, 2, This.Samples);
      This.Is_Valid := OK (S);
   end Parse;

   procedure Next (Buffer : Bytes; This : T; Position : in out Entries_Cursor; Element : out Entry_Type.T) is
   begin
      Parse_Entries_Element (Buffer, Position.Io, This, Element);
      Position.Left := (if Entry_Type.Valid (Element) then Position.Left - 1 else 0);
   end Next;

   procedure Get_Entries (Buffer : Bytes; This : T; Index : Length; Element : out Entry_Type.T) is
      Position : Entries_Cursor := Entries_First (This);
      Result   : Entry_Type.T;
   begin
      for I in 0 .. Index loop
         pragma Loop_Invariant (Belongs_To (Position, Buffer) and then Entry_Type.Belongs_To (Result, Buffer));
         exit when not Has_Element (Position);
         Next (Buffer, This, Position, Result);
      end loop;
      Element := Result;
   end Get_Entries;

   procedure Next (Buffer : Bytes; This : T; Position : in out Points_Cursor; Element : out Entry_Type.Point_Type.T) is
      pragma Unreferenced (This);
   begin
      Entry_Type.Point_Type.Parse (Buffer, Position.Io, Element);
      Position.Left := (if Entry_Type.Point_Type.Valid (Element) then Position.Left - 1 else 0);
   end Next;

   procedure Get_Points (Buffer : Bytes; This : T; Index : Length; Element : out Entry_Type.Point_Type.T) is
      Position : Points_Cursor := Points_First (This);
      Result   : Entry_Type.Point_Type.T;
   begin
      for I in 0 .. Index loop
         pragma Loop_Invariant (Belongs_To (Position, Buffer));
         exit when not Has_Element (Position);
         Next (Buffer, This, Position, Result);
      end loop;
      Element := Result;
   end Get_Points;

   procedure First_Entry (Buffer : Bytes; This : T; Result : out Entry_Type.T; Outcome : out Status_Kind) is
      L : Stream := This.Io;
   begin
      if Add_OK (5, S64 (Header_Type.Len_Name (This.Header))) then
         Seek (L, To_Size (5 + S64 (Header_Type.Len_Name (This.Header))));
      else
         Fail (L, Arithmetic_Error);
      end if;
      Entry_Type.Parse (Buffer, L, 0, Result);
      Outcome := Status (L);
   end First_Entry;

end Showcase;
