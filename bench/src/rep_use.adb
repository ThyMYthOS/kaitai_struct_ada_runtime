with Kaitai.Types; use Kaitai.Types;

package body Rep_Use
  with SPARK_Mode
is

   use Kaitai.Streams;

   package body Ref_Type is

      procedure Parse_Get
        (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Head : Bench_Rep.T; This : out T)
      is
         Element : Bench_Rep.Item_Type.T;
      begin
         This := (others => <>);
         Read_U4le (Buffer, S, This.Idx);
         if S64 (This.Idx) < S64 (Bench_Rep.Items_Count (Head)) then
            Bench_Rep.Get_Items (Buffer, Head, Length (This.Idx), Element);
            if Bench_Rep.Item_Type.Valid (Element) then
               Read_Bytes (S, To_Size (S64 (Bench_Rep.Item_Type.Len (Element))), This.Tag);
            else
               Fail (S, Illegal_Sequence);
            end if;
         else
            Fail (S, Arithmetic_Error);
         end if;
         This.Is_Valid := OK (S);
      end Parse_Get;

      procedure Parse_Fixed
        (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Head : Bench_Rep_Fixed.T; This : out T) is
      begin
         This := (others => <>);
         Read_U4le (Buffer, S, This.Idx);
         if S64 (This.Idx) < S64 (Bench_Rep_Fixed.Items_Count (Head)) then
            Read_Bytes (S, To_Size (S64 (Bench_Rep_Fixed.Items (Buffer, Head, Length (This.Idx)))), This.Tag);
         else
            Fail (S, Arithmetic_Error);
         end if;
         This.Is_Valid := OK (S);
      end Parse_Fixed;

      procedure Parse_Mod (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
      begin
         Read_U4le (Buffer, S, This.Idx);
         Read_Bytes (S, Length (This.Idx mod 8), This.Tag);
         This.Is_Valid := OK (S);
      end Parse_Mod;

   end Ref_Type;

   package body Tail_Type is

      procedure Parse_Get
        (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Head : Bench_Rep.T; This : out T)
      is
         Element : Bench_Rep.Item_Type.T;
         Count   : constant Length := Bench_Rep.Items_Count (Head);
      begin
         This := (others => <>);
         if Count > 0 then
            Bench_Rep.Get_Items (Buffer, Head, Count - 1, Element);
            if Bench_Rep.Item_Type.Valid (Element) then
               Read_Bytes (S, To_Size (S64 (Bench_Rep.Item_Type.Len (Element))), This.Tail);
            else
               Fail (S, Illegal_Sequence);
            end if;
         else
            Fail (S, Arithmetic_Error);
         end if;
         This.Is_Valid := OK (S);
      end Parse_Get;

      procedure Parse_Eos (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
         pragma Unreferenced (Buffer);
      begin
         Read_Bytes_Full (S, This.Tail);
         This.Is_Valid := OK (S);
      end Parse_Eos;

   end Tail_Type;

   package body Last_Kept is

      procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
         Element : Bench_Rep.Item_Type.T;
         Count   : U32;
      begin
         This := (others => <>);
         Read_U4le (Buffer, S, Count);
         This.Items_Count := To_Count (S64 (Count));
         for I in 1 .. This.Items_Count loop
            Bench_Rep.Item_Type.Parse (Buffer, S, Element);
            exit when not Bench_Rep.Item_Type.Valid (Element);
            This.Items_Last := Element;
            This.Has_Last := True;
            pragma
              Loop_Invariant
                (Is_Valid (S, Buffer)
                   and then Advanced (S'Loop_Entry, S)
                   and then This.Has_Last
                   and then Bench_Rep.Item_Type.Valid (This.Items_Last)
                   and then Bench_Rep.Item_Type.Belongs_To (This.Items_Last, Buffer));
         end loop;
         if This.Has_Last then
            Read_Bytes (S, To_Size (S64 (Bench_Rep.Item_Type.Len (This.Items_Last))), This.Tail);
         else
            Fail (S, Arithmetic_Error);
         end if;
         This.Is_Valid := OK (S);
      end Parse;

   end Last_Kept;

   package body Block_Type is

      procedure Parse_Get
        (Buffer : Kaitai.Types.Bytes;
         S      : in out Kaitai.Streams.Stream;
         Head   : Bench_Rep.T;
         Index  : Kaitai.Types.Length;
         This   : out T)
      is
         Element : Bench_Rep.Item_Type.T;
      begin
         This := (others => <>);
         if Index > 0 then
            if Index - 1 < Bench_Rep.Items_Count (Head) then
               Bench_Rep.Get_Items (Buffer, Head, Index - 1, Element);
               if Bench_Rep.Item_Type.Valid (Element) then
                  Read_Bytes (S, To_Size (S64 (Bench_Rep.Item_Type.Len (Element))), This.Buf);
               else
                  Fail (S, Illegal_Sequence);
               end if;
            else
               Fail (S, Arithmetic_Error);
            end if;
         end if;
         This.Is_Valid := OK (S);
      end Parse_Get;

      procedure Parse_Lockstep
        (Buffer : Kaitai.Types.Bytes;
         S      : in out Kaitai.Streams.Stream;
         Index  : Kaitai.Types.Length;
         Prev   : Kaitai.Types.U8;
         This   : out T)
      is
         pragma Unreferenced (Buffer);
      begin
         This := (others => <>);
         if Index > 0 then
            Read_Bytes (S, To_Size (S64 (Prev)), This.Buf);
         end if;
         This.Is_Valid := OK (S);
      end Parse_Lockstep;

   end Block_Type;

   package body Links is

      package body Link_Type is

         procedure Parse_Naive
           (Buffer : Kaitai.Types.Bytes;
            S      : in out Kaitai.Streams.Stream;
            Items  : View;
            Index  : Kaitai.Types.Length;
            This   : out T)
         is
            Before : T;
         begin
            This := (others => <>);
            Read_U1 (Buffer, S, This.Len);
            Read_Bytes (S, To_Size (S64 (This.Len)), This.Name);
            if Index > 0 then
               if Index - 1 < Items.Count then
                  Get_Naive (Buffer, Items, Index - 1, Before);
                  if Valid (Before) then
                     Read_Bytes (S, To_Size (S64 (Before.Len)), This.Extra);
                  else
                     Fail (S, Illegal_Sequence);
                  end if;
               else
                  Fail (S, Arithmetic_Error);
               end if;
            end if;
            This.Is_Valid := OK (S);
         end Parse_Naive;

         procedure Parse_Carried
           (Buffer : Kaitai.Types.Bytes;
            S      : in out Kaitai.Streams.Stream;
            Index  : Kaitai.Types.Length;
            Prev   : Kaitai.Types.U8;
            This   : out T) is
         begin
            This := (others => <>);
            Read_U1 (Buffer, S, This.Len);
            Read_Bytes (S, To_Size (S64 (This.Len)), This.Name);
            if Index > 0 then
               Read_Bytes (S, To_Size (S64 (Prev)), This.Extra);
            end if;
            This.Is_Valid := OK (S);
         end Parse_Carried;

      end Link_Type;

      procedure Get_Naive
        (Buffer : Kaitai.Types.Bytes; Items : View; Index : Kaitai.Types.Length; Link : out Link_Type.T)
      is
         L      : Kaitai.Streams.Stream := Items.Io;
         Result : Link_Type.T;
      begin
         for K in 0 .. Index loop
            pragma Loop_Invariant (Is_Valid (L, Buffer) and then Link_Type.Belongs_To (Result, Buffer));
            Link_Type.Parse_Naive (Buffer, L, Items, K, Result);
            exit when not Link_Type.Valid (Result);
         end loop;
         Link := Result;
      end Get_Naive;

      procedure Parse_Naive (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
         Element : Link_Type.T;
         Count   : U32;
         Items   : View;
      begin
         Read_U4le (Buffer, S, Count);
         This.Links_Io := S;
         This.Links_Count := To_Count (S64 (Count));
         Items := (Io => S, Count => This.Links_Count);
         for I in 1 .. This.Links_Count loop
            Link_Type.Parse_Naive (Buffer, S, Items, I - 1, Element);
            exit when not Link_Type.Valid (Element);
            pragma Loop_Invariant (Is_Valid (S, Buffer) and then Advanced (S'Loop_Entry, S));
         end loop;
         This.Is_Valid := OK (S);
      end Parse_Naive;

      procedure Parse_Carried (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T) is
         Element : Link_Type.T;
         Count   : U32;
         Prev    : U8 := 0;
      begin
         Read_U4le (Buffer, S, Count);
         This.Links_Io := S;
         This.Links_Count := To_Count (S64 (Count));
         for I in 1 .. This.Links_Count loop
            Link_Type.Parse_Carried (Buffer, S, I - 1, Prev, Element);
            exit when not Link_Type.Valid (Element);
            Prev := Link_Type.Len (Element);
            pragma Loop_Invariant (Is_Valid (S, Buffer) and then Advanced (S'Loop_Entry, S));
         end loop;
         This.Is_Valid := OK (S);
      end Parse_Carried;

      procedure Next_Naive (Buffer : Kaitai.Types.Bytes; This : T; Position : in out Cursor; Element : out Link_Type.T)
      is
      begin
         Link_Type.Parse_Naive
           (Buffer, Position.Io, (Io => This.Links_Io, Count => This.Links_Count), Position.Index, Element);
         if Link_Type.Valid (Element) then
            Position.Left := Position.Left - 1;
            if Position.Index < Length'Last then
               Position.Index := Position.Index + 1;
            end if;
         else
            Position.Left := 0;
         end if;
      end Next_Naive;

      procedure Next_Carried
        (Buffer : Kaitai.Types.Bytes; This : T; Position : in out Cursor; Element : out Link_Type.T)
      is
         pragma Unreferenced (This);
      begin
         Link_Type.Parse_Carried (Buffer, Position.Io, Position.Index, Position.Prev, Element);
         if Link_Type.Valid (Element) then
            Position.Left := Position.Left - 1;
            Position.Prev := Link_Type.Len (Element);
            if Position.Index < Length'Last then
               Position.Index := Position.Index + 1;
            end if;
         else
            Position.Left := 0;
         end if;
      end Next_Carried;

   end Links;

end Rep_Use;
