--  Parsers written by hand in the style of generated code, for the expressions that the compiler rejects today and
--  that use an element of a repetition of elements of a variable size (see formats/unsupported/).  They are built
--  over the generated Bench_Rep, whose Get_Items and Next are what an expression like items[idx] would call.
--
--  A value of the parent that an expression of a nested type needs is a parameter of its Parse, as for `_parent.x`
--  today; here it is the whole Bench_Rep.T or one integer, and the precondition says that the caller has parsed it.

with Bench_Rep;
with Bench_Rep_Fixed;
with Kaitai.Streams;
with Kaitai.Types;

package Rep_Use
  with SPARK_Mode, Always_Terminates
is

   use type Kaitai.Types.Length;

   --  ref: idx : u4, tag : size items[idx].len
   package Ref_Type is

      type T is private;

      function Valid (This : T) return Boolean;

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean;

      function Idx (This : T) return Kaitai.Types.U32
      with Pre => Valid (This);

      function Tag (This : T) return Kaitai.Types.Slice
      with Pre => Valid (This);

      --  The size comes from the element idx, which is parsed again from the first one on (Bench_Rep.Get_Items)
      procedure Parse_Get
        (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Head : Bench_Rep.T; This : out T)
      with
        Pre  =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Bench_Rep.Valid (Head)
          and then Bench_Rep.Belongs_To (Head, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S)
          and then Belongs_To (This, Buffer);

      --  The elements have a fixed size: the element idx is decoded from the buffer (Bench_Rep_Fixed.Items)
      procedure Parse_Fixed
        (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Head : Bench_Rep_Fixed.T; This : out T)
      with
        Pre  =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Bench_Rep_Fixed.Valid (Head)
          and then Bench_Rep_Fixed.Belongs_To (Head, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S)
          and then Belongs_To (This, Buffer);

      --  The size is idx mod 8, which is the size that the other two read from the element: no access, for comparison
      procedure Parse_Mod (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T)
      with
        Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S)
          and then Belongs_To (This, Buffer);

   private

      type T is record
         Is_Valid : Boolean := False;
         Idx      : Kaitai.Types.U32 := 0;
         Tag      : Kaitai.Types.Slice;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
      is (Kaitai.Types.Within (This.Tag, Buffer));

      function Idx (This : T) return Kaitai.Types.U32
      is (This.Idx);

      function Tag (This : T) return Kaitai.Types.Slice
      is (This.Tag);

   end Ref_Type;

   --  tail: bytes, size items.last.len
   package Tail_Type is

      type T is private;

      function Valid (This : T) return Boolean;

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean;

      function Tail (This : T) return Kaitai.Types.Slice
      with Pre => Valid (This);

      --  The last element is parsed again from the first one on: Bench_Rep.Get_Items (Items_Count - 1)
      procedure Parse_Get
        (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; Head : Bench_Rep.T; This : out T)
      with
        Pre  =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Bench_Rep.Valid (Head)
          and then Bench_Rep.Belongs_To (Head, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S)
          and then Belongs_To (This, Buffer);

      --  `size-eos`, which reads the same bytes: no access, for comparison
      procedure Parse_Eos (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T)
      with
        Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S)
          and then Belongs_To (This, Buffer);

   private

      type T is record
         Is_Valid : Boolean := False;
         Tail     : Kaitai.Types.Slice;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
      is (Kaitai.Types.Within (This.Tail, Buffer));

      function Tail (This : T) return Kaitai.Types.Slice
      is (This.Tail);

   end Tail_Type;

   --  num_items : u4, items : item[num_items], tail : size items.last.len.  Parse keeps the last element in the
   --  value, as one more component of the size of an element, so that the tail needs no second pass.
   package Last_Kept is

      type T is private;

      function Valid (This : T) return Boolean;

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean;

      function Items_Count (This : T) return Kaitai.Types.Length
      with Pre => Valid (This);

      function Tail (This : T) return Kaitai.Types.Slice
      with Pre => Valid (This);

      procedure Parse (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T)
      with
        Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S)
          and then Belongs_To (This, Buffer);

   private

      type T is record
         Is_Valid    : Boolean := False;
         Items_Count : Kaitai.Types.Length := 0;
         Has_Last    : Boolean := False;
         Items_Last  : Bench_Rep.Item_Type.T;
         Tail        : Kaitai.Types.Slice;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
      is (Kaitai.Types.Within (This.Tail, Buffer)
          and then (not This.Has_Last or else Bench_Rep.Item_Type.Belongs_To (This.Items_Last, Buffer)));

      function Items_Count (This : T) return Kaitai.Types.Length
      is (This.Items_Count);

      function Tail (This : T) return Kaitai.Types.Slice
      is (This.Tail);

   end Last_Kept;

   --  block: buf : size items[_index - 1].len, if _index > 0; the repetition `blocks` has as many elements as
   --  `items`, which is another repetition (of Bench_Rep)
   package Block_Type is

      type T is private;

      function Valid (This : T) return Boolean;

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean;

      function Buf (This : T) return Kaitai.Types.Slice
      with Pre => Valid (This);

      --  The element before is parsed again from the first one on: Bench_Rep.Get_Items (Index - 1)
      procedure Parse_Get
        (Buffer : Kaitai.Types.Bytes;
         S      : in out Kaitai.Streams.Stream;
         Head   : Bench_Rep.T;
         Index  : Kaitai.Types.Length;
         This   : out T)
      with
        Pre  =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Bench_Rep.Valid (Head)
          and then Bench_Rep.Belongs_To (Head, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S)
          and then Belongs_To (This, Buffer);

      --  The loop that calls this procedure goes through `items` alongside and hands on the len of the element
      --  before, as it would a value of `_parent`
      procedure Parse_Lockstep
        (Buffer : Kaitai.Types.Bytes;
         S      : in out Kaitai.Streams.Stream;
         Index  : Kaitai.Types.Length;
         Prev   : Kaitai.Types.U8;
         This   : out T)
      with
        Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S)
          and then Belongs_To (This, Buffer);

   private

      type T is record
         Is_Valid : Boolean := False;
         Buf      : Kaitai.Types.Slice;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
      is (Kaitai.Types.Within (This.Buf, Buffer));

      function Buf (This : T) return Kaitai.Types.Slice
      is (This.Buf);

   end Block_Type;

   --  num_items : u4, links : link[num_items]; link: len : u1, name : size len, extra : size links[_index - 1].len
   --  if _index > 0.  The repetition is the one that the expression refers to.
   package Links is

      --  Where the elements begin and how many there are, which is what an element needs to find another one
      type View is record
         Io    : Kaitai.Streams.Stream;
         Count : Kaitai.Types.Length := 0;
      end record;

      function Belongs_To (Items : View; Buffer : Kaitai.Types.Bytes) return Boolean
      is (Kaitai.Streams.Is_Valid (Items.Io, Buffer));

      package Link_Type is

         type T is private;

         function Valid (This : T) return Boolean;

         function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean;

         function Len (This : T) return Kaitai.Types.U8
         with Pre => Valid (This);

         function Extra (This : T) return Kaitai.Types.Slice
         with Pre => Valid (This);

         procedure Parse_Naive
           (Buffer : Kaitai.Types.Bytes;
            S      : in out Kaitai.Streams.Stream;
            Items  : View;
            Index  : Kaitai.Types.Length;
            This   : out T)
         with
           Pre                => Kaitai.Streams.Is_Valid (S, Buffer) and then Belongs_To (Items, Buffer),
           Post               =>
             Kaitai.Streams.Is_Valid (S, Buffer)
             and then Kaitai.Streams.Advanced (S'Old, S)
             and then Valid (This) = Kaitai.Streams.OK (S)
             and then Belongs_To (This, Buffer),
           Subprogram_Variant => (Decreases => Index, Decreases => 0);

         --  The element before is not parsed again: the loop that calls this procedure hands on its len
         procedure Parse_Carried
           (Buffer : Kaitai.Types.Bytes;
            S      : in out Kaitai.Streams.Stream;
            Index  : Kaitai.Types.Length;
            Prev   : Kaitai.Types.U8;
            This   : out T)
         with
           Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
           Post =>
             Kaitai.Streams.Is_Valid (S, Buffer)
             and then Kaitai.Streams.Advanced (S'Old, S)
             and then Valid (This) = Kaitai.Streams.OK (S)
             and then Belongs_To (This, Buffer);

      private

         type T is record
            Is_Valid : Boolean := False;
            Len      : Kaitai.Types.U8 := 0;
            Name     : Kaitai.Types.Slice;
            Extra    : Kaitai.Types.Slice;
         end record;

         function Valid (This : T) return Boolean
         is (This.Is_Valid);

         function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
         is (Kaitai.Types.Within (This.Name, Buffer) and then Kaitai.Types.Within (This.Extra, Buffer));

         function Len (This : T) return Kaitai.Types.U8
         is (This.Len);

         function Extra (This : T) return Kaitai.Types.Slice
         is (This.Extra);

      end Link_Type;

      --  The parser of an element and the procedure that delivers the element with a number call each other: the
      --  parser of the element Index needs the element Index - 1, which is parsed from the first one on, and each
      --  of those needs the one before it.  The number of element parses for one call of Get_Naive (Index) is
      --  2 ** (Index + 1) - 1.
      procedure Get_Naive
        (Buffer : Kaitai.Types.Bytes; Items : View; Index : Kaitai.Types.Length; Link : out Link_Type.T)
      with
        Pre                => Belongs_To (Items, Buffer),
        Post               => Link_Type.Belongs_To (Link, Buffer),
        Subprogram_Variant => (Decreases => Index, Decreases => 1);

      type T is private;

      function Valid (This : T) return Boolean;

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean;

      function Links_Count (This : T) return Kaitai.Types.Length
      with Pre => Valid (This);

      --  Parse reads each element once, to check it and to find the end
      procedure Parse_Naive (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T)
      with
        Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S)
          and then Belongs_To (This, Buffer);

      procedure Parse_Carried (Buffer : Kaitai.Types.Bytes; S : in out Kaitai.Streams.Stream; This : out T)
      with
        Pre  => Kaitai.Streams.Is_Valid (S, Buffer),
        Post =>
          Kaitai.Streams.Is_Valid (S, Buffer)
          and then Kaitai.Streams.Advanced (S'Old, S)
          and then Valid (This) = Kaitai.Streams.OK (S)
          and then Belongs_To (This, Buffer);

      type Cursor is private;

      function Belongs_To (Position : Cursor; Buffer : Kaitai.Types.Bytes) return Boolean;

      function First (This : T) return Cursor
      with Pre => Valid (This);

      function Remaining (Position : Cursor) return Kaitai.Types.Length;

      function Has_Element (Position : Cursor) return Boolean
      is (Remaining (Position) > 0);

      procedure Next_Naive (Buffer : Kaitai.Types.Bytes; This : T; Position : in out Cursor; Element : out Link_Type.T)
      with
        Pre  =>
          Valid (This)
          and then Belongs_To (This, Buffer)
          and then Belongs_To (Position, Buffer)
          and then Has_Element (Position),
        Post =>
          Belongs_To (Position, Buffer)
          and then Remaining (Position) < Remaining (Position'Old)
          and then Link_Type.Belongs_To (Element, Buffer);

      --  The cursor holds the len of the element before
      procedure Next_Carried
        (Buffer : Kaitai.Types.Bytes; This : T; Position : in out Cursor; Element : out Link_Type.T)
      with
        Pre  => Valid (This) and then Belongs_To (Position, Buffer) and then Has_Element (Position),
        Post =>
          Belongs_To (Position, Buffer)
          and then Remaining (Position) < Remaining (Position'Old)
          and then Link_Type.Belongs_To (Element, Buffer);

   private

      type T is record
         Is_Valid    : Boolean := False;
         Links_Io    : Kaitai.Streams.Stream;
         Links_Count : Kaitai.Types.Length := 0;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function Belongs_To (This : T; Buffer : Kaitai.Types.Bytes) return Boolean
      is (Kaitai.Streams.Is_Valid (This.Links_Io, Buffer));

      function Links_Count (This : T) return Kaitai.Types.Length
      is (This.Links_Count);

      type Cursor is record
         Io    : Kaitai.Streams.Stream;
         Left  : Kaitai.Types.Length := 0;
         Index : Kaitai.Types.Length := 0;
         Prev  : Kaitai.Types.U8 := 0;
      end record;

      function Belongs_To (Position : Cursor; Buffer : Kaitai.Types.Bytes) return Boolean
      is (Kaitai.Streams.Is_Valid (Position.Io, Buffer));

      function First (This : T) return Cursor
      is (Io => This.Links_Io, Left => This.Links_Count, Index => 0, Prev => 0);

      function Remaining (Position : Cursor) return Kaitai.Types.Length
      is (Position.Left);

   end Links;

end Rep_Use;
