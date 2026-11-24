with Ada.Containers.Vectors;
with Ada.Long_Float_Text_IO;
with Ada.Text_IO;
with Ada.Unchecked_Deallocate_Subpool;
with Ada.Unchecked_Deallocation;
with System.Storage_Pools.Subpools;

with Arenas;
with Bench_Support; use Bench_Support;
with Bench_Types;   use Bench_Types;
with Kaitai.Types;  use Kaitai.Types;
with Growable;

package body Strategies is

   Picks_Count : constant := 1000;

   ---------------------------------------------------------------------
   --  Parsing step shared by all strategies
   ---------------------------------------------------------------------

   procedure Parse_Next
     (Data : Bytes; Pos : in out Length; Tag : out U8; Len : out U16; Payload : out Slice; OK : out Boolean)
   with Inline_Always;

   procedure Parse_Next
     (Data : Bytes; Pos : in out Length; Tag : out U8; Len : out U16; Payload : out Slice; OK : out Boolean) is
   begin
      Tag := 0;
      Len := 0;
      Payload := (First => 1, Last => 0);
      OK := False;
      if Pos + 2 > Data'Last then
         return;
      end if;
      Tag := Data (Pos);
      Len := U16 (Data (Pos + 1)) or Shift_Left (U16 (Data (Pos + 2)), 8);
      if Pos + 2 + Length (Len) > Data'Last then
         return;
      end if;
      Payload := (First => Pos + 3, Last => Pos + 2 + Length (Len));
      Pos := Pos + 3 + Length (Len);
      OK := True;
   end Parse_Next;

   function Mix (Sum : U64; Tag : U8; Len : U16; Ends : U64) return U64
   is (Sum * 31 + U64 (Tag) + U64 (Len) * 7 + Ends)
   with Inline_Always;

   function Slice_Ends (Data : Bytes; S : Slice) return U64
   is (if S.Last < S.First then 0 else U64 (Data (S.First)) + U64 (Data (S.Last)))
   with Inline_Always;

   ---------------------------------------------------------------------
   --  Measurement harness
   ---------------------------------------------------------------------

   generic
      with procedure Build (Data : Bytes);
      with function Traverse (Data : Bytes) return U64;
      with function Pick (Data : Bytes; I : Positive) return U64;
      with procedure Teardown;
   procedure Measure (Name : String; Data : Bytes; Records : Positive; Reps : Positive; Phases : Phase_Count);

   procedure Measure (Name : String; Data : Bytes; Records : Positive; Reps : Positive; Phases : Phase_Count) is
      use Ada.Text_IO;

      Picks      : array (1 .. Picks_Count) of Positive;
      State      : Random_State := Seed (1234);
      Value      : U64;
      T_Build    : Samples (1 .. Reps);
      T_Traverse : Samples (1 .. Reps);
      T_Pick     : Samples (1 .. Reps);
      T_Teardown : Samples (1 .. Reps);
      Checksum   : U64 := 0;
      Pick_Sum   : U64 := 0;
      RSS_Before : constant Natural := RSS_KiB;
      RSS_Built  : Natural := 0;
      Watch      : Stopwatch;

      procedure Put_Value (X : Long_Float) is
      begin
         Put (" ");
         Ada.Long_Float_Text_IO.Put (X, Fore => 9, Aft => 2, Exp => 0);
      end Put_Value;
   begin
      for P of Picks loop
         Next (State, Value);
         P := Positive (Value mod U64 (Records) + 1);
      end loop;

      T_Build := [others => 0.0];
      T_Traverse := [others => 0.0];
      T_Pick := [others => 0.0];
      T_Teardown := [others => 0.0];

      for R in 1 .. Reps loop
         if Phases >= 1 then
            Watch := Start;
            Build (Data);
            T_Build (R) := Elapsed_NS (Watch) / Long_Float (Records);

            if R = 1 then
               RSS_Built := RSS_KiB;
            end if;
         end if;

         if Phases >= 2 then
            Watch := Start;
            Checksum := Traverse (Data);
            T_Traverse (R) := Elapsed_NS (Watch) / Long_Float (Records);
         end if;

         if Phases >= 3 then
            Watch := Start;
            Pick_Sum := 0;
            for P of Picks loop
               Pick_Sum := Pick_Sum + Pick (Data, P);
            end loop;
            T_Pick (R) := Elapsed_NS (Watch) / Long_Float (Picks_Count);
         end if;

         if Phases >= 4 then
            Watch := Start;
            Teardown;
            T_Teardown (R) := Elapsed_NS (Watch) / Long_Float (Records);
         end if;
      end loop;

      Put (Name);
      for I in Name'Length + 1 .. 16 loop
         Put (' ');
      end loop;
      Put_Value (Median (T_Build));
      Put_Value (Median (T_Traverse));
      Put_Value (Median (T_Pick));
      Put_Value (Median (T_Teardown));
      Put_Value (Long_Float (Integer'Max (RSS_Built - RSS_Before, 0)) * 1024.0 / Long_Float (Records));
      Put_Line ("  " & U64'Image (Checksum) & U64'Image (Pick_Sum));
   end Measure;

   ---------------------------------------------------------------------
   --  Lazy: nothing is stored
   ---------------------------------------------------------------------

   Lazy_Count : Natural := 0;

   procedure Lazy_Build (Data : Bytes) is
      Pos     : Length := Data'First;
      Tag     : U8;
      Len     : U16;
      Payload : Slice;
      OK      : Boolean;
   begin
      Lazy_Count := 0;
      while Pos <= Data'Last loop
         Parse_Next (Data, Pos, Tag, Len, Payload, OK);
         if not OK then
            raise Program_Error;
         end if;
         Lazy_Count := Lazy_Count + 1;
      end loop;
   end Lazy_Build;

   function Lazy_Traverse (Data : Bytes) return U64 is
      Pos     : Length := Data'First;
      Tag     : U8;
      Len     : U16;
      Payload : Slice;
      OK      : Boolean;
      Sum     : U64 := 0;
   begin
      for I in 1 .. Lazy_Count loop
         Parse_Next (Data, Pos, Tag, Len, Payload, OK);
         Sum := Mix (Sum, Tag, Len, Slice_Ends (Data, Payload));
      end loop;
      return Sum;
   end Lazy_Traverse;

   function Lazy_Pick (Data : Bytes; I : Positive) return U64 is
      Pos     : Length := Data'First;
      Tag     : U8 := 0;
      Len     : U16 := 0;
      Payload : Slice;
      OK      : Boolean;
   begin
      for J in 1 .. I loop
         Parse_Next (Data, Pos, Tag, Len, Payload, OK);
      end loop;
      return Mix (0, Tag, Len, Slice_Ends (Data, Payload));
   end Lazy_Pick;

   procedure Lazy_Teardown is null;

   procedure Measure_Lazy is new Measure (Lazy_Build, Lazy_Traverse, Lazy_Pick, Lazy_Teardown);

   ---------------------------------------------------------------------
   --  Nodes stored by value
   ---------------------------------------------------------------------

   type Node is record
      Tag     : U8;
      Len     : U16;
      Payload : Slice;
   end record;

   type Node_Array is array (Positive range <>) of Node;
   type Node_Array_Access is access Node_Array;

   --  Length arena: storage is provided up front, as a caller would do on a
   --  target without heap.  Capacity equals the number of records.
   Arena_Capacity : Natural := 0;
   Arena_Nodes    : Node_Array_Access;
   Arena_Count    : Natural := 0;
   Arena_Bytes    : Bytes_Access;
   Arena_Used     : Length := 0;

   procedure Index_Build (Data : Bytes) is
      Pos : Length := Data'First;
      N   : Node;
      OK  : Boolean;
   begin
      if Arena_Nodes = null then
         Arena_Nodes := new Node_Array (1 .. Arena_Capacity);
      end if;
      Arena_Count := 0;
      while Pos <= Data'Last loop
         Parse_Next (Data, Pos, N.Tag, N.Len, N.Payload, OK);
         if not OK or else Arena_Count = Arena_Capacity then
            raise Program_Error;
         end if;
         Arena_Count := Arena_Count + 1;
         Arena_Nodes (Arena_Count) := N;
      end loop;
   end Index_Build;

   function Index_Traverse (Data : Bytes) return U64 is
      Sum : U64 := 0;
   begin
      for N of Arena_Nodes (1 .. Arena_Count) loop
         Sum := Mix (Sum, N.Tag, N.Len, Slice_Ends (Data, N.Payload));
      end loop;
      return Sum;
   end Index_Traverse;

   function Index_Pick (Data : Bytes; I : Positive) return U64 is
      N : Node renames Arena_Nodes (I);
   begin
      return Mix (0, N.Tag, N.Len, Slice_Ends (Data, N.Payload));
   end Index_Pick;

   procedure Index_Teardown is
   begin
      Arena_Count := 0;
   end Index_Teardown;

   procedure Measure_Index is new Measure (Index_Build, Index_Traverse, Index_Pick, Index_Teardown);

   --  Length arena with payload copies in a byte arena

   procedure Index_Owned_Build (Data : Bytes) is
      Pos : Length := Data'First;
      N   : Node;
      OK  : Boolean;
      Len : Length;
   begin
      if Arena_Nodes = null then
         Arena_Nodes := new Node_Array (1 .. Arena_Capacity);
         Arena_Bytes := new Bytes (1 .. Data'Length);
      end if;
      Arena_Count := 0;
      Arena_Used := 0;
      while Pos <= Data'Last loop
         Parse_Next (Data, Pos, N.Tag, N.Len, N.Payload, OK);
         if not OK or else Arena_Count = Arena_Capacity then
            raise Program_Error;
         end if;
         Len := Length (N.Len);
         Arena_Bytes (Arena_Used + 1 .. Arena_Used + Len) := Data (N.Payload.First .. N.Payload.Last);
         N.Payload := (First => Arena_Used + 1, Last => Arena_Used + Len);
         Arena_Used := Arena_Used + Len;
         Arena_Count := Arena_Count + 1;
         Arena_Nodes (Arena_Count) := N;
      end loop;
   end Index_Owned_Build;

   function Index_Owned_Traverse (Data : Bytes) return U64 is
      pragma Unreferenced (Data);
      Sum : U64 := 0;
   begin
      for N of Arena_Nodes (1 .. Arena_Count) loop
         Sum := Mix (Sum, N.Tag, N.Len, Slice_Ends (Arena_Bytes.all, N.Payload));
      end loop;
      return Sum;
   end Index_Owned_Traverse;

   function Index_Owned_Pick (Data : Bytes; I : Positive) return U64 is
      pragma Unreferenced (Data);
      N : Node renames Arena_Nodes (I);
   begin
      return Mix (0, N.Tag, N.Len, Slice_Ends (Arena_Bytes.all, N.Payload));
   end Index_Owned_Pick;

   procedure Index_Owned_Teardown is
   begin
      Arena_Count := 0;
      Arena_Used := 0;
   end Index_Owned_Teardown;

   procedure Measure_Index_Owned is new
     Measure (Index_Owned_Build, Index_Owned_Traverse, Index_Owned_Pick, Index_Owned_Teardown);

   --  Growable array on the heap

   package Node_Vectors is new Growable (Node);

   Values : Node_Vectors.Vector;

   procedure Vector_Build (Data : Bytes) is
      Pos : Length := Data'First;
      N   : Node;
      OK  : Boolean;
   begin
      while Pos <= Data'Last loop
         Parse_Next (Data, Pos, N.Tag, N.Len, N.Payload, OK);
         if not OK then
            raise Program_Error;
         end if;
         Node_Vectors.Append (Values, N);
      end loop;
   end Vector_Build;

   function Vector_Traverse (Data : Bytes) return U64 is
      Sum : U64 := 0;
   begin
      for N of Values.Data (1 .. Values.Count) loop
         Sum := Mix (Sum, N.Tag, N.Len, Slice_Ends (Data, N.Payload));
      end loop;
      return Sum;
   end Vector_Traverse;

   function Vector_Pick (Data : Bytes; I : Positive) return U64 is
      N : Node renames Values.Data (I);
   begin
      return Mix (0, N.Tag, N.Len, Slice_Ends (Data, N.Payload));
   end Vector_Pick;

   procedure Vector_Teardown is
   begin
      Node_Vectors.Destroy (Values);
   end Vector_Teardown;

   procedure Measure_Vector is new Measure (Vector_Build, Vector_Traverse, Vector_Pick, Vector_Teardown);

   --  Heap array whose capacity is known before parsing, as for "repeat: expr"

   procedure Free_Nodes is new Ada.Unchecked_Deallocation (Node_Array, Node_Array_Access);

   Reserved       : Node_Array_Access;
   Reserved_Count : Natural := 0;

   procedure Reserved_Build (Data : Bytes) is
      Pos : Length := Data'First;
      N   : Node;
      OK  : Boolean;
   begin
      Reserved := new Node_Array (1 .. Arena_Capacity);
      Reserved_Count := 0;
      while Pos <= Data'Last loop
         Parse_Next (Data, Pos, N.Tag, N.Len, N.Payload, OK);
         if not OK or else Reserved_Count = Arena_Capacity then
            raise Program_Error;
         end if;
         Reserved_Count := Reserved_Count + 1;
         Reserved (Reserved_Count) := N;
      end loop;
   end Reserved_Build;

   function Reserved_Traverse (Data : Bytes) return U64 is
      Sum : U64 := 0;
   begin
      for N of Reserved (1 .. Reserved_Count) loop
         Sum := Mix (Sum, N.Tag, N.Len, Slice_Ends (Data, N.Payload));
      end loop;
      return Sum;
   end Reserved_Traverse;

   function Reserved_Pick (Data : Bytes; I : Positive) return U64 is
      N : Node renames Reserved (I);
   begin
      return Mix (0, N.Tag, N.Len, Slice_Ends (Data, N.Payload));
   end Reserved_Pick;

   procedure Reserved_Teardown is
   begin
      Free_Nodes (Reserved);
      Reserved_Count := 0;
   end Reserved_Teardown;

   procedure Measure_Reserved is new Measure (Reserved_Build, Reserved_Traverse, Reserved_Pick, Reserved_Teardown);

   --  Ada.Containers.Vectors

   package Ada_Vectors is new Ada.Containers.Vectors (Positive, Node);

   Ada_Values : Ada_Vectors.Vector;

   procedure Ada_Build (Data : Bytes) is
      Pos : Length := Data'First;
      N   : Node;
      OK  : Boolean;
   begin
      while Pos <= Data'Last loop
         Parse_Next (Data, Pos, N.Tag, N.Len, N.Payload, OK);
         if not OK then
            raise Program_Error;
         end if;
         Ada_Values.Append (N);
      end loop;
   end Ada_Build;

   function Ada_Traverse (Data : Bytes) return U64 is
      Sum : U64 := 0;
   begin
      for N of Ada_Values loop
         Sum := Mix (Sum, N.Tag, N.Len, Slice_Ends (Data, N.Payload));
      end loop;
      return Sum;
   end Ada_Traverse;

   function Ada_Pick (Data : Bytes; I : Positive) return U64 is
      N : constant Node := Ada_Values.Element (I);
   begin
      return Mix (0, N.Tag, N.Len, Slice_Ends (Data, N.Payload));
   end Ada_Pick;

   procedure Ada_Teardown is
   begin
      Ada_Values := Ada_Vectors.Empty_Vector;
   end Ada_Teardown;

   procedure Measure_Ada is new Measure (Ada_Build, Ada_Traverse, Ada_Pick, Ada_Teardown);

   ---------------------------------------------------------------------
   --  One object per node, referenced from a growable array of pointers.
   --  This is the shape of the object tree other Kaitai runtimes build.
   ---------------------------------------------------------------------

   pragma Warnings (Off, "is not referenced");

   generic
      type Payload_Type is private;
      with function Make (Data : Bytes; S : Slice) return Payload_Type;
      with function Ends (Data : Bytes; P : Payload_Type) return U64;
      with procedure Drop (P : in out Payload_Type);
   package Payload_Nodes is
      type P_Node is record
         Tag     : U8;
         Len     : U16;
         Payload : Payload_Type;
      end record;
   end Payload_Nodes;

   pragma Warnings (On, "is not referenced");

   generic
      with package PN is new Payload_Nodes (<>);
      type Node_Access is access PN.P_Node;
      with function Alloc (N : PN.P_Node) return Node_Access;
      with procedure Free_Node (P : in out Node_Access);
      with procedure Release_All;
      Free_Individually : Boolean;
   package Ptr_Impl is
      procedure Build (Data : Bytes);
      function Traverse (Data : Bytes) return U64;
      function Pick (Data : Bytes; I : Positive) return U64;
      procedure Teardown;
   end Ptr_Impl;

   package body Ptr_Impl is

      package Vectors is new Growable (Node_Access);

      Pointers : Vectors.Vector;

      procedure Build (Data : Bytes) is
         Pos     : Length := Data'First;
         Tag     : U8;
         Len     : U16;
         Payload : Slice;
         OK      : Boolean;
      begin
         while Pos <= Data'Last loop
            Parse_Next (Data, Pos, Tag, Len, Payload, OK);
            if not OK then
               raise Program_Error;
            end if;
            Vectors.Append (Pointers, Alloc ((Tag => Tag, Len => Len, Payload => PN.Make (Data, Payload))));
         end loop;
      end Build;

      function Traverse (Data : Bytes) return U64 is
         Sum : U64 := 0;
      begin
         for P of Pointers.Data (1 .. Pointers.Count) loop
            Sum := Mix (Sum, P.Tag, P.Len, PN.Ends (Data, P.Payload));
         end loop;
         return Sum;
      end Traverse;

      function Pick (Data : Bytes; I : Positive) return U64 is
         P : constant Node_Access := Pointers.Data (I);
      begin
         return Mix (0, P.Tag, P.Len, PN.Ends (Data, P.Payload));
      end Pick;

      procedure Teardown is
      begin
         if Free_Individually then
            for P of Pointers.Data (1 .. Pointers.Count) loop
               PN.Drop (P.Payload);
               Free_Node (P);
            end loop;
         end if;
         Vectors.Destroy (Pointers);
         Release_All;
      end Teardown;

   end Ptr_Impl;

   procedure No_Release is null;

   --  Pools and the subpool handle shared by the arena strategies.  Only one
   --  strategy runs per process.

   Pool     : Arenas.Bump_Pool;
   Sub_Pool : Arenas.Subpool_Pool;
   Handle   : System.Storage_Pools.Subpools.Subpool_Handle;

   procedure Ensure_Handle with Inline is
      use type System.Storage_Pools.Subpools.Subpool_Handle;
   begin
      if Handle = null then
         Handle := Arenas.Create_Subpool (Sub_Pool);
      end if;
   end Ensure_Handle;

   procedure Pool_Release is
   begin
      Arenas.Release (Pool);
   end Pool_Release;

   procedure Pool_Reset is
   begin
      Arenas.Reset (Pool);
   end Pool_Reset;

   procedure Subpool_Release is
      use type System.Storage_Pools.Subpools.Subpool_Handle;
   begin
      if Handle /= null then
         Ada.Unchecked_Deallocate_Subpool (Handle);
      end if;
   end Subpool_Release;

   --  Payload as slice into the input buffer

   pragma Warnings (Off, "formal parameter ""Data"" is not referenced");
   function Slice_Make (Data : Bytes; S : Slice) return Slice
   is (S)
   with Inline;
   pragma Warnings (On, "formal parameter ""Data"" is not referenced");
   procedure Slice_Drop (P : in out Slice) is null;

   package Slice_Nodes is new Payload_Nodes (Slice, Slice_Make, Slice_Ends, Slice_Drop);

   type Malloc_Access is access Slice_Nodes.P_Node;
   function Malloc_Alloc (N : Slice_Nodes.P_Node) return Malloc_Access
   is (new Slice_Nodes.P_Node'(N))
   with Inline;
   procedure Malloc_Free is new Ada.Unchecked_Deallocation (Slice_Nodes.P_Node, Malloc_Access);

   package Ptr_Malloc_Impl is new Ptr_Impl (Slice_Nodes, Malloc_Access, Malloc_Alloc, Malloc_Free, No_Release, True);
   procedure Measure_Ptr_Malloc is new
     Measure (Ptr_Malloc_Impl.Build, Ptr_Malloc_Impl.Traverse, Ptr_Malloc_Impl.Pick, Ptr_Malloc_Impl.Teardown);

   type Pool_Access is access Slice_Nodes.P_Node with Storage_Pool => Pool;
   function Pool_Alloc (N : Slice_Nodes.P_Node) return Pool_Access
   is (new Slice_Nodes.P_Node'(N))
   with Inline;
   procedure Pool_Free (P : in out Pool_Access) is null;

   package Ptr_Pool_Impl is new Ptr_Impl (Slice_Nodes, Pool_Access, Pool_Alloc, Pool_Free, Pool_Release, False);
   procedure Measure_Ptr_Pool is new
     Measure (Ptr_Pool_Impl.Build, Ptr_Pool_Impl.Traverse, Ptr_Pool_Impl.Pick, Ptr_Pool_Impl.Teardown);

   package Ptr_Pool_Kept_Impl is new Ptr_Impl (Slice_Nodes, Pool_Access, Pool_Alloc, Pool_Free, Pool_Reset, False);
   procedure Measure_Ptr_Pool_Kept is new
     Measure
       (Ptr_Pool_Kept_Impl.Build,
        Ptr_Pool_Kept_Impl.Traverse,
        Ptr_Pool_Kept_Impl.Pick,
        Ptr_Pool_Kept_Impl.Teardown);

   type Sub_Access is access Slice_Nodes.P_Node with Storage_Pool => Sub_Pool;
   function Sub_Alloc (N : Slice_Nodes.P_Node) return Sub_Access
   with Inline;
   function Sub_Alloc (N : Slice_Nodes.P_Node) return Sub_Access is
   begin
      Ensure_Handle;
      return new (Handle) Slice_Nodes.P_Node'(N);
   end Sub_Alloc;
   procedure Sub_Free (P : in out Sub_Access) is null;

   package Ptr_Subpool_Impl is new Ptr_Impl (Slice_Nodes, Sub_Access, Sub_Alloc, Sub_Free, Subpool_Release, False);
   procedure Measure_Ptr_Subpool is new
     Measure (Ptr_Subpool_Impl.Build, Ptr_Subpool_Impl.Traverse, Ptr_Subpool_Impl.Pick, Ptr_Subpool_Impl.Teardown);

   --  Payload copied into its own object, as runtimes with owned byte
   --  arrays and strings do

   generic
      type Owned is access Bytes;
   function Owned_Ends (Data : Bytes; P : Owned) return U64
   with Inline;

   function Owned_Ends (Data : Bytes; P : Owned) return U64 is
      pragma Unreferenced (Data);
   begin
      return (if P'Length = 0 then 0 else U64 (P (P'First)) + U64 (P (P'Last)));
   end Owned_Ends;

   --  ... from the default heap

   type Owned_M is access Bytes;
   function Owned_M_Make (Data : Bytes; S : Slice) return Owned_M
   is (new Bytes'(Data (S.First .. S.Last)))
   with Inline;
   function Owned_M_Ends is new Owned_Ends (Owned_M);
   procedure Owned_M_Drop is new Ada.Unchecked_Deallocation (Bytes, Owned_M);

   package Owned_M_Nodes is new Payload_Nodes (Owned_M, Owned_M_Make, Owned_M_Ends, Owned_M_Drop);

   type Owned_M_Access is access Owned_M_Nodes.P_Node;
   function Owned_M_Alloc (N : Owned_M_Nodes.P_Node) return Owned_M_Access
   is (new Owned_M_Nodes.P_Node'(N))
   with Inline;
   procedure Owned_M_Free is new Ada.Unchecked_Deallocation (Owned_M_Nodes.P_Node, Owned_M_Access);

   package Owned_Malloc_Impl is new
     Ptr_Impl (Owned_M_Nodes, Owned_M_Access, Owned_M_Alloc, Owned_M_Free, No_Release, True);
   procedure Measure_Owned_Malloc is new
     Measure (Owned_Malloc_Impl.Build, Owned_Malloc_Impl.Traverse, Owned_Malloc_Impl.Pick, Owned_Malloc_Impl.Teardown);

   --  ... from the bump pool

   type Owned_P is access Bytes with Storage_Pool => Pool;
   function Owned_P_Make (Data : Bytes; S : Slice) return Owned_P
   is (new Bytes'(Data (S.First .. S.Last)))
   with Inline;
   function Owned_P_Ends is new Owned_Ends (Owned_P);
   procedure Owned_P_Drop (P : in out Owned_P) is null;

   package Owned_P_Nodes is new Payload_Nodes (Owned_P, Owned_P_Make, Owned_P_Ends, Owned_P_Drop);

   type Owned_P_Access is access Owned_P_Nodes.P_Node with Storage_Pool => Pool;
   function Owned_P_Alloc (N : Owned_P_Nodes.P_Node) return Owned_P_Access
   is (new Owned_P_Nodes.P_Node'(N))
   with Inline;
   procedure Owned_P_Free (P : in out Owned_P_Access) is null;

   package Owned_Pool_Impl is new
     Ptr_Impl (Owned_P_Nodes, Owned_P_Access, Owned_P_Alloc, Owned_P_Free, Pool_Release, False);
   procedure Measure_Owned_Pool is new
     Measure (Owned_Pool_Impl.Build, Owned_Pool_Impl.Traverse, Owned_Pool_Impl.Pick, Owned_Pool_Impl.Teardown);

   package Owned_Pool_Kept_Impl is new
     Ptr_Impl (Owned_P_Nodes, Owned_P_Access, Owned_P_Alloc, Owned_P_Free, Pool_Reset, False);
   procedure Measure_Owned_Pool_Kept is new
     Measure
       (Owned_Pool_Kept_Impl.Build,
        Owned_Pool_Kept_Impl.Traverse,
        Owned_Pool_Kept_Impl.Pick,
        Owned_Pool_Kept_Impl.Teardown);

   --  ... from a subpool

   type Owned_S is access Bytes with Storage_Pool => Sub_Pool;
   function Owned_S_Make (Data : Bytes; S : Slice) return Owned_S
   with Inline;
   function Owned_S_Make (Data : Bytes; S : Slice) return Owned_S is
   begin
      Ensure_Handle;
      return new (Handle) Bytes'(Data (S.First .. S.Last));
   end Owned_S_Make;
   function Owned_S_Ends is new Owned_Ends (Owned_S);
   procedure Owned_S_Drop (P : in out Owned_S) is null;

   package Owned_S_Nodes is new Payload_Nodes (Owned_S, Owned_S_Make, Owned_S_Ends, Owned_S_Drop);

   type Owned_S_Access is access Owned_S_Nodes.P_Node with Storage_Pool => Sub_Pool;
   function Owned_S_Alloc (N : Owned_S_Nodes.P_Node) return Owned_S_Access
   with Inline;
   function Owned_S_Alloc (N : Owned_S_Nodes.P_Node) return Owned_S_Access is
   begin
      Ensure_Handle;
      return new (Handle) Owned_S_Nodes.P_Node'(N);
   end Owned_S_Alloc;
   procedure Owned_S_Free (P : in out Owned_S_Access) is null;

   package Owned_Subpool_Impl is new
     Ptr_Impl (Owned_S_Nodes, Owned_S_Access, Owned_S_Alloc, Owned_S_Free, Subpool_Release, False);
   procedure Measure_Owned_Subpool is new
     Measure
       (Owned_Subpool_Impl.Build,
        Owned_Subpool_Impl.Traverse,
        Owned_Subpool_Impl.Pick,
        Owned_Subpool_Impl.Teardown);

   ---------------------------------------------------------------------

   procedure Run
     (Which : Strategy; Records : Positive; Max_Payload : Natural; Reps : Positive; Phases : Phase_Count := 4)
   is
      Input : constant Bytes_Access := Generate_TLV (Records, Max_Payload);
      Name  : constant String := Strategy'Image (Which);
   begin
      Arena_Capacity := Records;
      case Which is
         when Lazy            =>
            Measure_Lazy (Name, Input.all, Records, Reps, Phases);

         when Index_Arena     =>
            Measure_Index (Name, Input.all, Records, Reps, Phases);

         when Index_Owned     =>
            Measure_Index_Owned (Name, Input.all, Records, Reps, Phases);

         when Vector_Values   =>
            Measure_Vector (Name, Input.all, Records, Reps, Phases);

         when Vector_Reserved =>
            Measure_Reserved (Name, Input.all, Records, Reps, Phases);

         when Ada_Vector      =>
            Measure_Ada (Name, Input.all, Records, Reps, Phases);

         when Ptr_Malloc      =>
            Measure_Ptr_Malloc (Name, Input.all, Records, Reps, Phases);

         when Ptr_Pool        =>
            Measure_Ptr_Pool (Name, Input.all, Records, Reps, Phases);

         when Ptr_Pool_Kept   =>
            Measure_Ptr_Pool_Kept (Name, Input.all, Records, Reps, Phases);

         when Ptr_Subpool     =>
            Measure_Ptr_Subpool (Name, Input.all, Records, Reps, Phases);

         when Owned_Malloc    =>
            Measure_Owned_Malloc (Name, Input.all, Records, Reps, Phases);

         when Owned_Pool      =>
            Measure_Owned_Pool (Name, Input.all, Records, Reps, Phases);

         when Owned_Pool_Kept =>
            Measure_Owned_Pool_Kept (Name, Input.all, Records, Reps, Phases);

         when Owned_Subpool   =>
            Measure_Owned_Subpool (Name, Input.all, Records, Reps, Phases);
      end case;
   end Run;

end Strategies;
