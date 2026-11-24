--  Parser for extras.ksy, written by hand as the model of what the Kaitai
--  Struct compiler generates for "process", for a type that contains
--  itself, and for references to _parent and _root.  See docs/codegen.md.

with Kaitai.Streams; use Kaitai.Streams;
with Kaitai.Types;   use Kaitai.Types;

package Extras
  with SPARK_Mode, Always_Terminates
is

   --  How deep values of a type that contains itself may be nested.  Every
   --  level takes room on the stack while it is parsed, and nothing checks
   --  on a light run-time library that the stack is large enough.
   Max_Depth : constant := 8;

   --  type inner

   package Inner_Type is

      type T is private;

      function Valid (This : T) return Boolean;

      procedure Parse (Buffer : Bytes; S : in out Stream; This : out T)
      with
        Pre  => Is_Valid (S, Buffer),
        Post => Is_Valid (S, Buffer) and then Advanced (S'Old, S) and then Valid (This) = OK (S);

      function A (This : T) return U16
      with Pre => Valid (This);

      function B (This : T) return U8
      with Pre => Valid (This);

   private

      type T is record
         Is_Valid : Boolean := False;
         A        : U16 := 0;
         B        : U8 := 0;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function A (This : T) return U16
      is (This.A);

      function B (This : T) return U8
      is (This.B);

   end Inner_Type;

   --  type item

   package Item_Type is

      type T is private;

      function Valid (This : T) return Boolean;

      function Belongs_To (This : T; Buffer : Bytes) return Boolean;

      --  Parent_Len_Secret is _parent.len_secret, Root_Key is _root.key
      procedure Parse (Buffer : Bytes; S : in out Stream; Parent_Len_Secret : U8; Root_Key : U8; This : out T)
      with
        Pre  => Is_Valid (S, Buffer),
        Post =>
          Is_Valid (S, Buffer)
          and then Advanced (S'Old, S)
          and then Valid (This) = OK (S)
          and then Belongs_To (This, Buffer);

      function Value (This : T) return Slice
      with Pre => Valid (This);

      function Has_Extra (This : T) return Boolean
      with Pre => Valid (This);

      function Extra (This : T) return U8
      with Pre => Valid (This) and then Has_Extra (This);

   private

      type T is record
         Is_Valid          : Boolean := False;
         Parent_Len_Secret : U8 := 0;
         Root_Key          : U8 := 0;
         Value             : Slice;
         Has_Extra         : Boolean := False;
         Extra             : U8 := 0;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function Belongs_To (This : T; Buffer : Bytes) return Boolean
      is (Within (This.Value, Buffer));

      function Value (This : T) return Slice
      is (This.Value);

      function Has_Extra (This : T) return Boolean
      is (This.Has_Extra);

      function Extra (This : T) return U8
      is (This.Extra);

   end Item_Type;

   --  type node, which contains itself

   package Node_Type is

      type T is private;

      function Valid (This : T) return Boolean;

      function Belongs_To (This : T; Buffer : Bytes) return Boolean;

      --  Root_Key is _root.key.  Depth is the number of levels of nesting
      --  that are accepted below this value; deeper ones make the stream
      --  fail with Limit_Exceeded.
      procedure Parse (Buffer : Bytes; S : in out Stream; Root_Key : U8; Depth : Natural; This : out T)
      with
        Pre                => Is_Valid (S, Buffer),
        Post               =>
          Is_Valid (S, Buffer)
          and then Advanced (S'Old, S)
          and then Valid (This) = OK (S)
          and then Belongs_To (This, Buffer),
        Subprogram_Variant => (Decreases => Depth, Decreases => 1);

      function Tag (This : T) return U8
      with Pre => Valid (This);

      function Num_Children (This : T) return U8
      with Pre => Valid (This);

      --  children: not kept, but parsed again when asked for

      function Children_Count (This : T) return Length
      with Pre => Valid (This);

      type Children_Cursor is private;

      function Belongs_To (Position : Children_Cursor; Buffer : Bytes) return Boolean;

      function Children_First (This : T) return Children_Cursor
      with Pre => Valid (This);

      function Remaining (Position : Children_Cursor) return Length;

      function Has_Element (Position : Children_Cursor) return Boolean
      is (Remaining (Position) > 0);

      procedure Next (Buffer : Bytes; This : T; Position : in out Children_Cursor; Element : out T)
      with
        Pre  => Valid (This) and then Belongs_To (Position, Buffer) and then Has_Element (Position),
        Post =>
          Belongs_To (Position, Buffer)
          and then Remaining (Position) < Remaining (Position'Old)
          and then Belongs_To (Element, Buffer);

      procedure Get_Children (Buffer : Bytes; This : T; Index : Length; Element : out T)
      with
        Pre  => Valid (This) and then Belongs_To (This, Buffer) and then Index < Children_Count (This),
        Post => Belongs_To (Element, Buffer);

      function Has_Weight (This : T) return Boolean
      with Pre => Valid (This);

      function Weight (This : T) return U8
      with Pre => Valid (This) and then Has_Weight (This);

   private

      type Children_Cursor is record
         Io   : Stream;
         Left : Length := 0;
      end record;

      type T is record
         Is_Valid       : Boolean := False;
         Root_Key       : U8 := 0;
         Depth          : Natural := 0;
         Tag            : U8 := 0;
         Num_Children   : U8 := 0;
         Children_Io    : Stream;
         Children_Count : Length := 0;
         Has_Weight     : Boolean := False;
         Weight         : U8 := 0;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function Belongs_To (This : T; Buffer : Bytes) return Boolean
      is (Is_Valid (This.Children_Io, Buffer));

      function Tag (This : T) return U8
      is (This.Tag);

      function Num_Children (This : T) return U8
      is (This.Num_Children);

      function Children_Count (This : T) return Length
      is (This.Children_Count);

      function Belongs_To (Position : Children_Cursor; Buffer : Bytes) return Boolean
      is (Is_Valid (Position.Io, Buffer));

      function Children_First (This : T) return Children_Cursor
      is (Io => This.Children_Io, Left => This.Children_Count);

      function Remaining (Position : Children_Cursor) return Length
      is (Position.Left);

      function Has_Weight (This : T) return Boolean
      is (This.Has_Weight);

      function Weight (This : T) return U8
      is (This.Weight);

   end Node_Type;

   --  type extras

   type T is private;

   function Valid (This : T) return Boolean;

   function Belongs_To (This : T; Buffer : Bytes) return Boolean;

   procedure Parse (Buffer : Bytes; S : in out Stream; This : out T)
   with
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Is_Valid (S, Buffer)
       and then Advanced (S'Old, S)
       and then Valid (This) = OK (S)
       and then Belongs_To (This, Buffer);

   function Key (This : T) return U8
   with Pre => Valid (This);

   function Len_Secret (This : T) return U8
   with Pre => Valid (This);

   --  secret: kept as it is in the input.  Secret undoes the processing
   --  and writes the result to an array of the caller.

   function Secret_Raw (This : T) return Slice
   with Pre => Valid (This);

   procedure Secret (Buffer : Bytes; This : T; Target : in out Bytes; Last : out Length; Outcome : out Status_Kind)
   with
     Pre  => Valid (This) and then Belongs_To (This, Buffer) and then Target'First >= 1,
     Post =>
       (if Outcome = Success
        then Last = Target'First + Size (Secret_Raw (This)) - 1
        else Last = Target'First - 1 and then Outcome = Capacity_Exceeded);

   function Len_Packed (This : T) return U8
   with Pre => Valid (This);

   --  packed: kept as it is in the input.  Packed undoes the processing
   --  into Storage and parses the value from there, so that what the
   --  value refers to lies in Storage and not in Buffer.

   function Packed_Raw (This : T) return Slice
   with Pre => Valid (This);

   procedure Packed
     (Buffer : Bytes; This : T; Storage : in out Bytes; Result : out Inner_Type.T; Outcome : out Status_Kind)
   with
     Pre  => Valid (This) and then Belongs_To (This, Buffer) and then Storage'First >= 1,
     Post => Inner_Type.Valid (Result) = (Outcome = Success);

   --  items: not kept, but parsed again when asked for

   function Items_Count (This : T) return Length
   with Pre => Valid (This);

   type Items_Cursor is private;

   function Belongs_To (Position : Items_Cursor; Buffer : Bytes) return Boolean;

   function Items_First (This : T) return Items_Cursor
   with Pre => Valid (This);

   function Remaining (Position : Items_Cursor) return Length;

   function Has_Element (Position : Items_Cursor) return Boolean
   is (Remaining (Position) > 0);

   procedure Next (Buffer : Bytes; This : T; Position : in out Items_Cursor; Element : out Item_Type.T)
   with
     Pre  => Valid (This) and then Belongs_To (Position, Buffer) and then Has_Element (Position),
     Post =>
       Belongs_To (Position, Buffer)
       and then Remaining (Position) < Remaining (Position'Old)
       and then Item_Type.Belongs_To (Element, Buffer);

   procedure Get_Items (Buffer : Bytes; This : T; Index : Length; Element : out Item_Type.T)
   with
     Pre  => Valid (This) and then Belongs_To (This, Buffer) and then Index < Items_Count (This),
     Post => Item_Type.Belongs_To (Element, Buffer);

   function Tree (This : T) return Node_Type.T
   with Pre => Valid (This), Post => Node_Type.Valid (Tree'Result);

private

   type Items_Cursor is record
      Io   : Stream;
      Left : Length := 0;
   end record;

   type T is record
      Is_Valid    : Boolean := False;
      Key         : U8 := 0;
      Len_Secret  : U8 := 0;
      Secret      : Slice;
      Len_Packed  : U8 := 0;
      Packed      : Slice;
      Items_Io    : Stream;
      Items_Count : Length := 0;
      Tree        : Node_Type.T;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid and then Node_Type.Valid (This.Tree));

   function Belongs_To (This : T; Buffer : Bytes) return Boolean
   is (Within (This.Secret, Buffer)
       and then Within (This.Packed, Buffer)
       and then Is_Valid (This.Items_Io, Buffer)
       and then Node_Type.Belongs_To (This.Tree, Buffer));

   function Key (This : T) return U8
   is (This.Key);

   function Len_Secret (This : T) return U8
   is (This.Len_Secret);

   function Secret_Raw (This : T) return Slice
   is (This.Secret);

   function Len_Packed (This : T) return U8
   is (This.Len_Packed);

   function Packed_Raw (This : T) return Slice
   is (This.Packed);

   function Items_Count (This : T) return Length
   is (This.Items_Count);

   function Belongs_To (Position : Items_Cursor; Buffer : Bytes) return Boolean
   is (Is_Valid (Position.Io, Buffer));

   function Items_First (This : T) return Items_Cursor
   is (Io => This.Items_Io, Left => This.Items_Count);

   function Remaining (Position : Items_Cursor) return Length
   is (Position.Left);

   function Tree (This : T) return Node_Type.T
   is (This.Tree);

end Extras;
