with Ada.Unchecked_Deallocation;

package body Arenas is

   use type System.Address;

   procedure Free is new Ada.Unchecked_Deallocation (Chunk, Chunk_Access);

   procedure Bump
     (List : in out Chunk_List; Address : out System.Address; Size : Storage_Count; Alignment : Storage_Count)
   with Inline;

   procedure Bump
     (List : in out Chunk_List; Address : out System.Address; Size : Storage_Count; Alignment : Storage_Count)
   is
      Align : constant Integer_Address := Integer_Address (Storage_Count'Max (Alignment, 1));
   begin
      if List.Head /= null then
         declare
            Base    : constant Integer_Address := To_Integer (List.Head.Data'Address);
            Start   : constant Integer_Address := (Base + Integer_Address (List.Used) + Align - 1) / Align * Align;
            New_End : constant Integer_Address := Start - Base + Integer_Address (Size);
         begin
            if New_End <= Integer_Address (List.Head.Size) then
               List.Used := Storage_Count (New_End);
               Address := To_Address (Start);
               return;
            end if;
         end;
      end if;

      declare
         Wanted    : constant Storage_Count := Storage_Count'Max (Default_Chunk_Size, Size + Storage_Count (Align));
         New_Chunk : Chunk_Access;
         Base      : Integer_Address;
         Start     : Integer_Address;
      begin
         if List.Spare /= null and then List.Spare.Size >= Wanted then
            New_Chunk := List.Spare;
            List.Spare := New_Chunk.Next;
         else
            New_Chunk := new Chunk (Wanted);
         end if;
         Base := To_Integer (New_Chunk.Data'Address);
         Start := (Base + Align - 1) / Align * Align;
         New_Chunk.Next := List.Head;
         List.Head := New_Chunk;
         List.Used := Storage_Count (Start - Base) + Size;
         Address := To_Address (Start);
      end;
   end Bump;

   procedure Release (List : in out Chunk_List) is
      Current : Chunk_Access := List.Head;
      Next    : Chunk_Access;
   begin
      while Current /= null loop
         Next := Current.Next;
         Free (Current);
         Current := Next;
      end loop;
      Current := List.Spare;
      while Current /= null loop
         Next := Current.Next;
         Free (Current);
         Current := Next;
      end loop;
      List := (Head => null, Used => 0, Spare => null);
   end Release;

   procedure Reset (List : in out Chunk_List) is
      Current : Chunk_Access := List.Head;
      Next    : Chunk_Access;
   begin
      while Current /= null loop
         Next := Current.Next;
         Current.Next := List.Spare;
         List.Spare := Current;
         Current := Next;
      end loop;
      List.Head := null;
      List.Used := 0;
   end Reset;

   overriding
   procedure Allocate
     (Pool : in out Bump_Pool; Address : out System.Address; Size : Storage_Count; Alignment : Storage_Count) is
   begin
      Bump (Pool.Chunks, Address, Size, Alignment);
   end Allocate;

   procedure Release (Pool : in out Bump_Pool) is
   begin
      Release (Pool.Chunks);
   end Release;

   procedure Reset (Pool : in out Bump_Pool) is
   begin
      Reset (Pool.Chunks);
   end Reset;

   type Arena_Subpool_Access is access all Arena_Subpool;

   procedure Free is new Ada.Unchecked_Deallocation (Arena_Subpool, Arena_Subpool_Access);

   overriding
   function Create_Subpool (Pool : in out Subpool_Pool) return not null System.Storage_Pools.Subpools.Subpool_Handle is
      use System.Storage_Pools.Subpools;
      Object : constant Arena_Subpool_Access := new Arena_Subpool;
      Handle : constant Subpool_Handle := Subpool_Handle (Object);
   begin
      Set_Pool_Of_Subpool (Handle, Pool);
      return Handle;
   end Create_Subpool;

   overriding
   procedure Allocate_From_Subpool
     (Pool      : in out Subpool_Pool;
      Address   : out System.Address;
      Size      : Storage_Count;
      Alignment : Storage_Count;
      Subpool   : not null System.Storage_Pools.Subpools.Subpool_Handle)
   is
      pragma Unreferenced (Pool);
   begin
      Bump (Arena_Subpool (Subpool.all).Chunks, Address, Size, Alignment);
   end Allocate_From_Subpool;

   overriding
   procedure Deallocate_Subpool
     (Pool : in out Subpool_Pool; Subpool : in out System.Storage_Pools.Subpools.Subpool_Handle)
   is
      pragma Unreferenced (Pool);
      Object : Arena_Subpool_Access := Arena_Subpool_Access (Subpool);
   begin
      Release (Object.Chunks);
      Free (Object);
      Subpool := null;
   end Deallocate_Subpool;

end Arenas;
