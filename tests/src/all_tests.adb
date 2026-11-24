with Arithmetic_Tests;
with Bits_Tests;
with Byte_Arrays_Tests;
with Decoding_Tests;
with Examples_Tests;
with Extras_Tests;
with Processing_Tests;
with Sample_Parser_Tests;
with Showcase_Tests;
with Streams_Tests;
with Strings_Tests;
with Substreams_Tests;
with Test_Support;
with Writers_Tests;
with Zlib_Tests;

procedure All_Tests is
begin
   Decoding_Tests.Run;
   Streams_Tests.Run;
   Bits_Tests.Run;
   Byte_Arrays_Tests.Run;
   Strings_Tests.Run;
   Substreams_Tests.Run;
   Processing_Tests.Run;
   Zlib_Tests.Run;
   Arithmetic_Tests.Run;
   Sample_Parser_Tests.Run;
   Examples_Tests.Run;
   Showcase_Tests.Run;
   Extras_Tests.Run;
   Writers_Tests.Run;
   Test_Support.Summary;
end All_Tests;
