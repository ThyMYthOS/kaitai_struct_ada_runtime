--  Parser for showcase.ksy, written by hand as the model of what the Kaitai
--  Struct compiler generates.  See docs/codegen.md.

with Kaitai.Arithmetic; use Kaitai.Arithmetic;
with Kaitai.Decoding;
with Kaitai.Streams;    use Kaitai.Streams;
with Kaitai.Types;      use Kaitai.Types;

package Showcase
  with SPARK_Mode, Always_Terminates
is

   --  enum kind

   type Kind_Enum is (Kind_Small, Kind_Big);

   function Is_Kind_Enum (Value : S64) return Boolean
   is (Value in 1 | 2);

   function To_Kind_Enum (Value : S64) return Kind_Enum
   is (case Value is
         when 1      => Kind_Small,
         when others => Kind_Big)
   with Pre => Is_Kind_Enum (Value);

   function To_Integer (Value : Kind_Enum) return S64
   is (case Value is
         when Kind_Small => 1,
         when Kind_Big   => 2);

   --  type header

   package Header_Type is

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

      function Version (This : T) return U8
      with Pre => Valid (This);

      function Flags (This : T) return U8
      with Pre => Valid (This);

      function Len_Name (This : T) return U8
      with Pre => Valid (This);

      function Name (This : T) return Slice
      with Pre => Valid (This);

   private

      type T is record
         Is_Valid : Boolean := False;
         Version  : U8 := 0;
         Flags    : U8 := 0;
         Len_Name : U8 := 0;
         Name     : Slice;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function Belongs_To (This : T; Buffer : Bytes) return Boolean
      is (Within (This.Name, Buffer));

      function Version (This : T) return U8
      is (This.Version);

      function Flags (This : T) return U8
      is (This.Flags);

      function Len_Name (This : T) return U8
      is (This.Len_Name);

      function Name (This : T) return Slice
      is (This.Name);

   end Header_Type;

   --  type entry

   package Entry_Type is

      --  type entry::point

      package Point_Type is

         type T is private;

         function Valid (This : T) return Boolean;

         procedure Parse (Buffer : Bytes; S : in out Stream; This : out T)
         with
           Pre  => Is_Valid (S, Buffer),
           Post => Is_Valid (S, Buffer) and then Advanced (S'Old, S) and then Valid (This) = OK (S);

         function X (This : T) return S16
         with Pre => Valid (This);

         function Y (This : T) return S16
         with Pre => Valid (This);

      private

         type T is record
            Is_Valid : Boolean := False;
            X        : S16 := 0;
            Y        : S16 := 0;
         end record;

         function Valid (This : T) return Boolean
         is (This.Is_Valid);

         function X (This : T) return S16
         is (This.X);

         function Y (This : T) return S16
         is (This.Y);

      end Point_Type;

      --  type entry::text

      package Text_Type is

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

         function Value (This : T) return Slice
         with Pre => Valid (This);

      private

         type T is record
            Is_Valid : Boolean := False;
            Value    : Slice;
         end record;

         function Valid (This : T) return Boolean
         is (This.Is_Valid);

         function Belongs_To (This : T; Buffer : Bytes) return Boolean
         is (Within (This.Value, Buffer));

         function Value (This : T) return Slice
         is (This.Value);

      end Text_Type;

      type T is private;

      function Valid (This : T) return Boolean;

      function Belongs_To (This : T; Buffer : Bytes) return Boolean;

      procedure Parse (Buffer : Bytes; S : in out Stream; Flags : U8; This : out T)
      with
        Pre  => Is_Valid (S, Buffer),
        Post =>
          Is_Valid (S, Buffer)
          and then Advanced (S'Old, S)
          and then Valid (This) = OK (S)
          and then Belongs_To (This, Buffer);

      function Flags (This : T) return U8
      with Pre => Valid (This);

      function Code (This : T) return U8
      with Pre => Valid (This);

      --  body: its type depends on code

      type Body_Kind is (Body_Is_Point, Body_Is_Text, Body_Is_None);

      function Body_Case (This : T) return Body_Kind
      with Pre => Valid (This);

      function Body_As_Point (This : T) return Point_Type.T
      with
        Pre  => Valid (This) and then Body_Case (This) = Body_Is_Point,
        Post => Point_Type.Valid (Body_As_Point'Result);

      function Body_As_Text (This : T) return Text_Type.T
      with Pre => Valid (This) and then Body_Case (This) = Body_Is_Text, Post => Text_Type.Valid (Body_As_Text'Result);

      function Has_Extra (This : T) return Boolean
      with Pre => Valid (This);

      function Extra (This : T) return U8
      with Pre => Valid (This) and then Has_Extra (This);

   private

      type Body_Variant (Kind : Body_Kind := Body_Is_None) is record
         case Kind is
            when Body_Is_Point =>
               Point : Point_Type.T;

            when Body_Is_Text =>
               Text : Text_Type.T;

            when Body_Is_None =>
               null;
         end case;
      end record;

      type T is record
         Is_Valid  : Boolean := False;
         Flags     : U8 := 0;
         Code      : U8 := 0;
         Body_F    : Body_Variant;
         Has_Extra : Boolean := False;
         Extra     : U8 := 0;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid
          and then (case This.Body_F.Kind is
                      when Body_Is_Point => Point_Type.Valid (This.Body_F.Point),
                      when Body_Is_Text  => Text_Type.Valid (This.Body_F.Text),
                      when Body_Is_None  => True));

      function Belongs_To (This : T; Buffer : Bytes) return Boolean
      is (case This.Body_F.Kind is
            when Body_Is_Point => True,
            when Body_Is_Text  => Text_Type.Belongs_To (This.Body_F.Text, Buffer),
            when Body_Is_None  => True);

      function Flags (This : T) return U8
      is (This.Flags);

      function Code (This : T) return U8
      is (This.Code);

      function Body_Case (This : T) return Body_Kind
      is (This.Body_F.Kind);

      function Body_As_Point (This : T) return Point_Type.T
      is (This.Body_F.Point);

      function Body_As_Text (This : T) return Text_Type.T
      is (This.Body_F.Text);

      function Has_Extra (This : T) return Boolean
      is (This.Has_Extra);

      function Extra (This : T) return U8
      is (This.Extra);

   end Entry_Type;

   --  type log

   package Log_Type is

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

      --  records: not kept, but parsed again when asked for

      function Records_Count (This : T) return Length
      with Pre => Valid (This);

      type Records_Cursor is private;

      function Belongs_To (Position : Records_Cursor; Buffer : Bytes) return Boolean;

      function Records_First (This : T) return Records_Cursor
      with Pre => Valid (This);

      function Remaining (Position : Records_Cursor) return Length;

      function Has_Element (Position : Records_Cursor) return Boolean
      is (Remaining (Position) > 0);

      procedure Next (Buffer : Bytes; This : T; Position : in out Records_Cursor; Element : out Entry_Type.Point_Type.T)
      with
        Pre  => Valid (This) and then Belongs_To (Position, Buffer) and then Has_Element (Position),
        Post => Belongs_To (Position, Buffer) and then Remaining (Position) < Remaining (Position'Old);

      procedure Get_Records (Buffer : Bytes; This : T; Index : Length; Element : out Entry_Type.Point_Type.T)
      with Pre => Valid (This) and then Belongs_To (This, Buffer) and then Index < Records_Count (This);

   private

      type Records_Cursor is record
         Io   : Stream;
         Left : Length := 0;
      end record;

      type T is record
         Is_Valid      : Boolean := False;
         Records_Io    : Stream;
         Records_Count : Length := 0;
      end record;

      function Valid (This : T) return Boolean
      is (This.Is_Valid);

      function Belongs_To (This : T; Buffer : Bytes) return Boolean
      is (Is_Valid (This.Records_Io, Buffer));

      function Records_Count (This : T) return Length
      is (This.Records_Count);

      function Belongs_To (Position : Records_Cursor; Buffer : Bytes) return Boolean
      is (Is_Valid (Position.Io, Buffer));

      function Records_First (This : T) return Records_Cursor
      is (Io => This.Records_Io, Left => This.Records_Count);

      function Remaining (Position : Records_Cursor) return Length
      is (Position.Left);

   end Log_Type;

   --  type showcase

   type T is private;

   function Valid (This : T) return Boolean;

   function Belongs_To (This : T; Buffer : Bytes) return Boolean;

   procedure Parse (Buffer : Bytes; S : in out Stream; Scale : U16; This : out T)
   with
     Pre  => Is_Valid (S, Buffer),
     Post =>
       Is_Valid (S, Buffer)
       and then Advanced (S'Old, S)
       and then Valid (This) = OK (S)
       and then Belongs_To (This, Buffer);

   function Scale (This : T) return U16
   with Pre => Valid (This);

   function Kind_Value (This : T) return U8
   with Pre => Valid (This);

   function Kind (This : T) return Kind_Enum
   with Pre => Valid (This) and then Is_Kind_Enum (S64 (Kind_Value (This)));

   function Num_Entries (This : T) return U16
   with Pre => Valid (This);

   function Header (This : T) return Header_Type.T
   with Pre => Valid (This), Post => Header_Type.Valid (Header'Result);

   --  entries: not kept, but parsed again when asked for, one after the
   --  other through a cursor or one by its index

   function Entries_Count (This : T) return Length
   with Pre => Valid (This);

   type Entries_Cursor is private;

   function Belongs_To (Position : Entries_Cursor; Buffer : Bytes) return Boolean;

   function Entries_First (This : T) return Entries_Cursor
   with Pre => Valid (This);

   function Remaining (Position : Entries_Cursor) return Length;

   function Has_Element (Position : Entries_Cursor) return Boolean
   is (Remaining (Position) > 0);

   --  Parse the element at Position and move on.  An element that Parse
   --  accepted is valid here as well, as long as Buffer holds what was
   --  parsed; that is not proven, so check Entry_Type.Valid (Element).
   procedure Next (Buffer : Bytes; This : T; Position : in out Entries_Cursor; Element : out Entry_Type.T)
   with
     Pre  => Valid (This) and then Belongs_To (Position, Buffer) and then Has_Element (Position),
     Post =>
       Belongs_To (Position, Buffer)
       and then Remaining (Position) < Remaining (Position'Old)
       and then Entry_Type.Belongs_To (Element, Buffer);

   --  The element with the given index, counted from 0.  Those before it
   --  are parsed on the way.
   procedure Get_Entries (Buffer : Bytes; This : T; Index : Length; Element : out Entry_Type.T)
   with
     Pre  => Valid (This) and then Belongs_To (This, Buffer) and then Index < Entries_Count (This),
     Post => Entry_Type.Belongs_To (Element, Buffer);

   function Has_Tail_Len (This : T) return Boolean
   with Pre => Valid (This);

   function Tail_Len (This : T) return U32
   with Pre => Valid (This) and then Has_Tail_Len (This);

   --  points: not kept, but parsed again when asked for

   function Points_Count (This : T) return Length
   with Pre => Valid (This);

   type Points_Cursor is private;

   function Belongs_To (Position : Points_Cursor; Buffer : Bytes) return Boolean;

   function Points_First (This : T) return Points_Cursor
   with Pre => Valid (This);

   function Remaining (Position : Points_Cursor) return Length;

   function Has_Element (Position : Points_Cursor) return Boolean
   is (Remaining (Position) > 0);

   procedure Next (Buffer : Bytes; This : T; Position : in out Points_Cursor; Element : out Entry_Type.Point_Type.T)
   with
     Pre  => Valid (This) and then Belongs_To (Position, Buffer) and then Has_Element (Position),
     Post => Belongs_To (Position, Buffer) and then Remaining (Position) < Remaining (Position'Old);

   procedure Get_Points (Buffer : Bytes; This : T; Index : Length; Element : out Entry_Type.Point_Type.T)
   with Pre => Valid (This) and then Belongs_To (This, Buffer) and then Index < Points_Count (This);

   function Len_Log (This : T) return U8
   with Pre => Valid (This);

   function Log (This : T) return Log_Type.T
   with Pre => Valid (This), Post => Log_Type.Valid (Log'Result);

   --  samples: decoded from the buffer when asked for

   function Samples_Count (This : T) return Length
   with Pre => Valid (This);

   function Samples (Buffer : Bytes; This : T; Index : Length) return U16
   with Pre => Valid (This) and then Belongs_To (This, Buffer) and then Index < Samples_Count (This);

   --  instance total

   function Has_Total (This : T) return Boolean
   with Pre => Valid (This);

   function Total (This : T) return S64
   with Pre => Valid (This) and then Has_Total (This);

   --  instance first_entry: parsed when asked for

   procedure First_Entry (Buffer : Bytes; This : T; Result : out Entry_Type.T; Outcome : out Status_Kind)
   with
     Pre  => Valid (This) and then Belongs_To (This, Buffer),
     Post => Entry_Type.Valid (Result) = (Outcome = Success) and then Entry_Type.Belongs_To (Result, Buffer);

private

   type Entries_Cursor is record
      Io   : Stream;
      Left : Length := 0;
   end record;

   type Points_Cursor is record
      Io   : Stream;
      Left : Length := 0;
   end record;

   type T is record
      Is_Valid      : Boolean := False;
      Io            : Stream;
      Scale         : U16 := 0;
      Kind          : U8 := 0;
      Num_Entries   : U16 := 0;
      Header        : Header_Type.T;
      Entries_Io    : Stream;
      Entries_Count : Length := 0;
      Has_Tail_Len  : Boolean := False;
      Tail_Len      : U32 := 0;
      Points_Io     : Stream;
      Points_Count  : Length := 0;
      Len_Log       : U8 := 0;
      Log           : Log_Type.T;
      Samples       : Slice;
   end record;

   function Valid (This : T) return Boolean
   is (This.Is_Valid
       and then Header_Type.Valid (This.Header)
       and then Log_Type.Valid (This.Log)
       and then Size (This.Samples) mod 2 = 0);

   function Belongs_To (This : T; Buffer : Bytes) return Boolean
   is (Is_Valid (This.Io, Buffer)
       and then Header_Type.Belongs_To (This.Header, Buffer)
       and then Is_Valid (This.Entries_Io, Buffer)
       and then Is_Valid (This.Points_Io, Buffer)
       and then Log_Type.Belongs_To (This.Log, Buffer)
       and then Within (This.Samples, Buffer));

   function Points_Count (This : T) return Length
   is (This.Points_Count);

   function Belongs_To (Position : Points_Cursor; Buffer : Bytes) return Boolean
   is (Is_Valid (Position.Io, Buffer));

   function Points_First (This : T) return Points_Cursor
   is (Io => This.Points_Io, Left => This.Points_Count);

   function Remaining (Position : Points_Cursor) return Length
   is (Position.Left);

   function Len_Log (This : T) return U8
   is (This.Len_Log);

   function Log (This : T) return Log_Type.T
   is (This.Log);

   function Scale (This : T) return U16
   is (This.Scale);

   function Kind_Value (This : T) return U8
   is (This.Kind);

   function Kind (This : T) return Kind_Enum
   is (To_Kind_Enum (S64 (This.Kind)));

   function Num_Entries (This : T) return U16
   is (This.Num_Entries);

   function Header (This : T) return Header_Type.T
   is (This.Header);

   function Entries_Count (This : T) return Length
   is (This.Entries_Count);

   function Belongs_To (Position : Entries_Cursor; Buffer : Bytes) return Boolean
   is (Is_Valid (Position.Io, Buffer));

   function Entries_First (This : T) return Entries_Cursor
   is (Io => This.Entries_Io, Left => This.Entries_Count);

   function Remaining (Position : Entries_Cursor) return Length
   is (Position.Left);

   function Has_Tail_Len (This : T) return Boolean
   is (This.Has_Tail_Len);

   function Tail_Len (This : T) return U32
   is (This.Tail_Len);

   function Samples_Count (This : T) return Length
   is (Size (This.Samples) / 2);

   function Samples (Buffer : Bytes; This : T; Index : Length) return U16
   is (Kaitai.Decoding.U16_LE (Buffer, This.Samples.First + Index * 2));

   function Has_Total (This : T) return Boolean
   is (Multiply_OK (S64 (This.Num_Entries), S64 (This.Scale))
       and then Add_OK (Multiply (S64 (This.Num_Entries), S64 (This.Scale)), S64 (Header_Type.Version (This.Header))));

   function Total (This : T) return S64
   is (Multiply (S64 (This.Num_Entries), S64 (This.Scale)) + S64 (Header_Type.Version (This.Header)));

end Showcase;
