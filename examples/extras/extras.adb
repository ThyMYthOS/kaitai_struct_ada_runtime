with Kaitai.Processing;

package body Extras
  with SPARK_Mode
is

   package body Inner_Type is

      procedure Parse (Buffer : Bytes; S : in out Stream; This : out T) is
      begin
         Read_U2be (Buffer, S, This.A);
         Read_U1 (Buffer, S, This.B);
         This.Is_Valid := OK (S);
      end Parse;

   end Inner_Type;

   package body Item_Type is

      procedure Parse (Buffer : Bytes; S : in out Stream; Parent_Len_Secret : U8; Root_Key : U8; This : out T) is
      begin
         This := (others => <>);
         This.Parent_Len_Secret := Parent_Len_Secret;
         This.Root_Key := Root_Key;
         Read_Bytes (S, To_Size (S64 (This.Parent_Len_Secret)), This.Value);
         if S64 (This.Root_Key) > 1 then
            This.Has_Extra := True;
            Read_U1 (Buffer, S, This.Extra);
         end if;
         This.Is_Valid := OK (S);
      end Parse;

   end Item_Type;

   package body Node_Type is

      --  Parse one element of children
      procedure Parse_Children_Element (Buffer : Bytes; S : in out Stream; This : T; Element : out T)
      with
        Pre                => Is_Valid (S, Buffer),
        Post               =>
          Is_Valid (S, Buffer)
          and then Advanced (S'Old, S)
          and then (if Valid (Element) then OK (S))
          and then Belongs_To (Element, Buffer),
        Subprogram_Variant => (Decreases => This.Depth, Decreases => 0);

      procedure Parse_Children_Element (Buffer : Bytes; S : in out Stream; This : T; Element : out T) is
      begin
         if This.Depth > 0 then
            Parse (Buffer, S, This.Root_Key, This.Depth - 1, Element);
         else
            Fail (S, Limit_Exceeded);
            Element := (others => <>);
         end if;
      end Parse_Children_Element;

      procedure Parse (Buffer : Bytes; S : in out Stream; Root_Key : U8; Depth : Natural; This : out T) is
         Element : T;
      begin
         This := (others => <>);
         This.Root_Key := Root_Key;
         This.Depth := Depth;
         Read_U1 (Buffer, S, This.Tag);
         Read_U1 (Buffer, S, This.Num_Children);

         This.Children_Io := S;
         This.Children_Count := To_Count (S64 (This.Num_Children));
         for I in 1 .. This.Children_Count loop
            Parse_Children_Element (Buffer, S, This, Element);
            exit when not Valid (Element);
            pragma Loop_Invariant (Is_Valid (S, Buffer) and then Advanced (S'Loop_Entry, S));
         end loop;

         if S64 (This.Root_Key) /= 0 then
            This.Has_Weight := True;
            Read_U1 (Buffer, S, This.Weight);
         end if;
         This.Is_Valid := OK (S);
      end Parse;

      procedure Next (Buffer : Bytes; This : T; Position : in out Children_Cursor; Element : out T) is
      begin
         Parse_Children_Element (Buffer, Position.Io, This, Element);
         Position.Left := (if Valid (Element) then Position.Left - 1 else 0);
      end Next;

      procedure Get_Children (Buffer : Bytes; This : T; Index : Length; Element : out T) is
         Position : Children_Cursor := Children_First (This);
         Result   : T;
      begin
         for I in 0 .. Index loop
            pragma Loop_Invariant (Belongs_To (Position, Buffer) and then Belongs_To (Result, Buffer));
            exit when not Has_Element (Position);
            Next (Buffer, This, Position, Result);
         end loop;
         Element := Result;
      end Get_Children;

   end Node_Type;

   --  Parse one element of items
   procedure Parse_Items_Element (Buffer : Bytes; S : in out Stream; This : T; Element : out Item_Type.T)
   with
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Is_Valid (S, Buffer)
       and then Advanced (S'Old, S)
       and then (if Item_Type.Valid (Element) then OK (S))
       and then Item_Type.Belongs_To (Element, Buffer);

   procedure Parse_Items_Element (Buffer : Bytes; S : in out Stream; This : T; Element : out Item_Type.T) is
   begin
      Item_Type.Parse (Buffer, S, This.Len_Secret, This.Key, Element);
   end Parse_Items_Element;

   procedure Parse (Buffer : Bytes; S : in out Stream; This : out T) is
      Element : Item_Type.T;
   begin
      This := (others => <>);
      Read_U1 (Buffer, S, This.Key);
      Read_U1 (Buffer, S, This.Len_Secret);
      Read_Bytes (S, To_Size (S64 (This.Len_Secret)), This.Secret);
      Read_U1 (Buffer, S, This.Len_Packed);
      Read_Bytes (S, To_Size (S64 (This.Len_Packed)), This.Packed);

      This.Items_Io := S;
      This.Items_Count := To_Count (2);
      for I in 1 .. This.Items_Count loop
         Parse_Items_Element (Buffer, S, This, Element);
         exit when not Item_Type.Valid (Element);
         pragma Loop_Invariant (Is_Valid (S, Buffer) and then Advanced (S'Loop_Entry, S));
      end loop;

      Node_Type.Parse (Buffer, S, This.Key, Max_Depth, This.Tree);
      This.Is_Valid := OK (S);
   end Parse;

   procedure Secret (Buffer : Bytes; This : T; Target : in out Bytes; Last : out Length; Outcome : out Status_Kind) is
   begin
      if Size (This.Secret) > Target'Length then
         Last := Target'First - 1;
         Outcome := Capacity_Exceeded;
      elsif Is_Empty (This.Secret) then
         Last := Target'First - 1;
         Outcome := Success;
      else
         Last := Target'First + (Size (This.Secret) - 1);
         Kaitai.Processing.Xor_One
           (Buffer (This.Secret.First .. This.Secret.Last), This.Key, Target (Target'First .. Last));
         Outcome := Success;
      end if;
   end Secret;

   procedure Packed
     (Buffer : Bytes; This : T; Storage : in out Bytes; Result : out Inner_Type.T; Outcome : out Status_Kind)
   is
      Last : Length;
      Sub  : Stream;
      None : Inner_Type.T;
   begin
      if Size (This.Packed) > Storage'Length then
         Result := None;
         Outcome := Capacity_Exceeded;
      else
         Last := Storage'First + Size (This.Packed) - 1;
         if not Is_Empty (This.Packed) then
            Kaitai.Processing.Rotate_Left
              (Buffer (This.Packed.First .. This.Packed.Last), 3, Storage (Storage'First .. Last));
         end if;
         Sub := Open (Storage (Storage'First .. Last));
         Inner_Type.Parse (Storage, Sub, Result);
         Outcome := Status (Sub);
      end if;
   end Packed;

   procedure Next (Buffer : Bytes; This : T; Position : in out Items_Cursor; Element : out Item_Type.T) is
   begin
      Parse_Items_Element (Buffer, Position.Io, This, Element);
      Position.Left := (if Item_Type.Valid (Element) then Position.Left - 1 else 0);
   end Next;

   procedure Get_Items (Buffer : Bytes; This : T; Index : Length; Element : out Item_Type.T) is
      Position : Items_Cursor := Items_First (This);
      Result   : Item_Type.T;
   begin
      for I in 0 .. Index loop
         pragma Loop_Invariant (Belongs_To (Position, Buffer) and then Item_Type.Belongs_To (Result, Buffer));
         exit when not Has_Element (Position);
         Next (Buffer, This, Position, Result);
      end loop;
      Element := Result;
   end Get_Items;

end Extras;
