import SweetXml
defmodule CastXMLPony do
  use Memoize
  def main(args) do
    opts = [help: :boolean, xmlfile: :string, structs: :boolean, uses: :boolean, list: :boolean, generate: :boolean, functions: :boolean]
    aliases = [h: :help, x: :xmlfile, s: :structs, u: :uses, f: :functions, l: :list, g: :generate]
    options = [strict: opts, aliases: aliases]
    {opts,fids} = OptionParser.parse!(args, options)

    optmap = Enum.into(opts, Map.new)
             |> Map.put(:fileid, fids)

    if (Map.get(optmap, :help, false)) do
      printhelp()
      :erlang.halt()
    end

    #    if (Map.get(optmap, :list, false) and (Map.get(optmap, :fileid, false) == false)), do: listfiles(optmap.xmlfile)
    IO.inspect(optmap)
    if (Map.get(optmap, :list, false) and is_list(Map.get(optmap, :fileid, false))) do
      if (Map.get(optmap, :structs, false)) do
        IO.puts("Structs:")
        Enum.map(optmap.fileid, &({&1,structs(optmap.xmlfile, &1)}))
        |> Enum.map(fn({fid,symbols}) -> Enum.map(symbols, &("#{fid}:#{&1}")) |> Enum.join("\n") end)
        |> Enum.join("\n")
        |> IO.puts
      end
      if (Map.get(optmap, :uses, false)) do
        IO.puts("Functions:")
        Enum.map(optmap.fileid, &({&1,functions(optmap.xmlfile, &1)}))
        |> Enum.map(fn({fid,symbols}) -> Enum.map(symbols, &("#{fid}:#{&1}")) |> Enum.join("\n") end)
        |> Enum.join("\n")
        |> IO.puts
      end
    end

    if (Map.get(optmap, :generate, false) and is_list(Map.get(optmap, :fileid, false))) do
      if (Map.get(optmap, :structs, false)) do
        Enum.map(optmap.fileid, &(structs(optmap.xmlfile, &1)))
        |> List.flatten
        |> Enum.map(&(useStructReal(optmap.xmlfile, &1)))
        |> Enum.join("\n\n")
        |> IO.puts
      end
      if (Map.get(optmap, :uses, false)) do
        Enum.map(optmap.fileid, &(functions(optmap.xmlfile, &1)))
        |> List.flatten
        |> Enum.reject(&(Regex.match?(~r/^_/, &1)))
        |> Enum.map(&(useFunction(optmap.xmlfile, &1)))
        |> Enum.join("\n")
        |> IO.puts
      end
    end

    if (Map.get(optmap, :functions, false)) do
      IO.puts("Generate functions for: #{inspect(Map.get(optmap, :fileid, []))}")
      Enum.map(optmap.fileid, &(functions(optmap.xmlfile, &1)))
      |> List.flatten
      |> Enum.uniq
      |> Enum.map(&(genFunctionWrapper(optmap.xmlfile, &1)))
      |> Enum.join("\n")
      |> IO.puts


    end
  end

  def listfiles(filename) do
    f(filename)
    |> xpath(~x"/CastXML/File"l, name: ~x"./@name"s, id: ~x"./@id"s)
    |> Enum.map(fn(%{id: id, name: name}) -> "#{id}: #{name}" end)
    |> Enum.map(&IO.puts/1)
  end

  defmemo f(filename) do
    File.read!(filename)
    |> xpath(~x".")
  end

  def structs(filename, fid) do
    f(filename)
    |> xpath(~x"/CastXML/Struct[@file='#{fid}']/@name"ls)
  end

  def useStructReal(filename, structname) do
    structByName(filename, structname)
  end

  def structByName(filename, name) do
    smap =
    f(filename)
    |> xpath(~x"/CastXML/Struct[@name='#{name}']",
               id:   ~x"./@id"s,
               name: ~x"./@name"s,
               members: ~x"./@members"s,
               align: ~x"./@align"s,
               size: ~x"./@size"s
    )

    case Map.get(smap, :members) do
      "" -> "struct #{toPonyPrimitive(smap.name)}"
      x -> fields =
           String.split(x, " ") 
           |> Enum.map(&(fieldMap(filename, &1)))
           |> Enum.map(&defineField/1)
           |> Enum.join("\n")

      """
      struct #{toPonyPrimitive(smap.name)}
      #{fields}
      """
    end
  end

  def defineField(%{name: name, ponytype: ponytype, offset: offset}) do
    #    "  var p#{name}: #{String.replace(ponytype, " tag ", "")} = #{ponydefault(ponytype)} // offset: #{offset}"
    "  var p#{name}: #{ponytype} = #{ponydefault(ponytype)} // offset: #{offset}"
  end


  def ponydefault("Bool"), do: false

  def ponydefault(x = "I8"), do: "#{x}(0)"
  def ponydefault(x = "I16"), do: "#{x}(0)"
  def ponydefault(x = "I32"), do: "#{x}(0)"
  def ponydefault(x = "I64"), do: "#{x}(0)"
  def ponydefault(x = "I128"), do: "#{x}(0)"
  def ponydefault(x = "ISize"), do: "#{x}(0)"
  def ponydefault(x = "ILong"), do: "#{x}(0)"

  def ponydefault(x = "U8"), do: "#{x}(0)"
  def ponydefault(x = "U16"), do: "#{x}(0)"
  def ponydefault(x = "U32"), do: "#{x}(0)"
  def ponydefault(x = "U64"), do: "#{x}(0)"
  def ponydefault(x = "U128"), do: "#{x}(0)"
  def ponydefault(x = "USize"), do: "#{x}(0)"
  def ponydefault(x = "ULong"), do: "#{x}(0)"

  def ponydefault(x = "F32"), do: "#{x}(0)"
  def ponydefault(x = "F64"), do: "#{x}(0)"
  def ponydefault(x = "F128"), do: "#{x}(0)"
  def ponydefault(x = <<"Pointer"::utf8, _rest::binary>>), do: String.replace_trailing(x, " tag", "")
  def ponydefault(x = <<"NullablePointer"::utf8, _rest::binary>>), do: "#{String.replace_trailing(x, " tag", "")}.none()"
  def ponydefault(x), do: x

  def isPonyPrimitive("Bool"), do: true

  def fieldMap(filename, id) do
    map =
    f(filename)
    |> xpath(~x"/CastXML/Field[@id='#{id}']",
               name: ~x"./@name"s,
               type: ~x"./@type"s,
               offset: ~x"./@offset"s)

    Map.put(map, :ponytype, recurseType(filename, map.type))
  end

  def useFunction(filename, functionname) do
    txt = useFunctionReal(filename, functionname)
    case Regex.match?(~r/FUNCTIONPOINTER/, txt) do
      true -> "// Not Implemented Yet: #{txt}"
      false -> txt
    end
  end
  def useFunctionReal(filename, functionname) do
    %{args: args, name: name, returns: returns} = functionByName(filename, functionname)
    #    "use @#{name}[#{recurseType(filename, returns)}](#{makeargs(args,filename)})"
    "use @#{name}[#{String.replace(recurseType(filename, returns), " tag", "")}](#{makeargs(args,filename)})"
  end

  def genFunctionWrapper(filename, functionname) do
    %{args: args, name: name, returns: returns} = functionByName(filename, functionname)
    
    rvorig = recurseType(filename, returns) |> String.replace(" tag", "")
    rv     = %{name: "rv", type: returns} |> makeponyarg(filename)
    """
      fun #{name}(#{makeponyargs(args,filename)})#{rv.type} =>
        var tmpvar: #{rvorig} = @#{functionname}[#{rvorig}](#{makeCargs(args,filename)})
        #{translateReturn(rvorig)}
    """
  end

  def translateReturn("Pointer[U8]") do
    """
    let p: String iso = String.from_cstring(tmpvar).clone()
        consume p
    """
  end
  def translateReturn(x), do: "tmpvar"

  def makeCargs(arglist, filename) do
    Enum.map(arglist, &(makeCarg(&1,filename)))
    |> Enum.map(&("p#{&1.name}#{&1.type}"))
    |> Enum.join(", ")
  end
  def makeponyargs(arglist, filename) do
    Enum.map(arglist, &(makeponyarg(&1,filename)))
    |> Enum.map(&("p#{&1.name}#{&1.type}"))
    |> Enum.join(", ")
  end

  def makeCarg(%{name: name, type: type}, filename) do
    %{name: name, type: ponyCArgOverride(recurseType(filename, type))}
  end
  def makeponyarg(%{name: name, type: type}, filename) do
    %{name: name, type: ponyArgOverride(recurseType(filename, type))}
  end

  def ponyCArgOverride("Pointer[U8] tag"), do: ".cstring()"
  def ponyCArgOverride(x),                 do: ""
  def ponyArgOverride("Pointer[U8] tag"),  do: ": String"
  def ponyArgOverride(x),                  do: ": #{x}"




  def makeargs([], _filename), do: ""
  def makeargs(listofargs, filename) do
    len = Enum.count(listofargs)

    Range.new(0,len-1)
    |> Enum.map(&({&1, recurseType(filename, Enum.at(listofargs, &1).type)}))
    |> Enum.map(fn({x,type}) -> "anon#{x}: #{type}" end)
    |> Enum.join(", ")
  end

  def defineTypes(filename, fid) do
    functions(filename, fid)
    |> Enum.map(&(functionByName(filename, &1)))
    |> Enum.map(fn(%{args: list, returns: returns}) -> [returns | Enum.map(list, &(&1.type))] end)
    |> List.flatten
    |> Enum.uniq
  end
    






  def allFromType(filename, type) do
    f(filename)
    |> xpath(~x"//#{type}"l)
  end
  def functions(filename, fid) do
    f(filename)
    |> xpath(~x"/CastXML/Function[@file='#{fid}']/@name"ls)
  end

  def functionByName(filename, name) do
    f(filename)
    |> xpath(~x"/CastXML/Function[@name='#{name}']",
               name: ~x"./@name"s,
               returns: ~x"./@returns"s,
               args: [~x"./Argument"l, name: ~x"./@name"s,
                                       type: ~x"./@type"s ]
    )
  end

  defmemo recurseType(filename, id) do
    recurseType(filename, typeByID(filename, id), [])
    |> rationalizeType()
  end

  def rationalizeType(list) do
    list
    |> Enum.reject(fn(%{recordType: type}) -> type in [:ElaboratedType, :Typedef, :CvQualifiedType] end)
    |> Enum.reduce("", &rationalizeType/2)
  end

  def rationalizeType(%{name: name,  recordType: :Struct}, acc), do: toPonyPrimitive(name) <> acc
  def rationalizeType(%{name: _name, recordType: :Enumeration}, _acc), do: "I32"
  def rationalizeType(%{name: _name, recordType: :FunctionType}, _acc), do: "FUNCTIONPOINTER"
  def rationalizeType(%{name: _name, recordType: :Field}, acc), do: acc
  def rationalizeType(%{name: _name, recordType: :ArrayType}, acc), do: "Pointer[#{acc}]"

  def rationalizeType(%{name: _name, recordType: :PointerType}, "I8"), do: "Pointer[U8] tag"
  def rationalizeType(%{name: _name, recordType: :PointerType}, "U8"), do: "Pointer[U8] tag"
  def rationalizeType(%{name: _name, recordType: :PointerType}, x = <<"Pointer"::utf8, _rest::binary>>), do: "Pointer[#{x}]"
  def rationalizeType(%{name: _name, recordType: :PointerType}, x = <<"NullablePointer"::utf8, _rest::binary>>), do: "Pointer[#{x}]"
  def rationalizeType(%{name: _name, recordType: :PointerType}, "None"), do: "Pointer[U8]"
  def rationalizeType(%{name: _name, recordType: :PointerType}, "FUNCTIONPOINTER"), do: "Pointer[FUNCTIONPOINTER]"
  def rationalizeType(%{name: _name, recordType: :PointerType}, acc) do
    case isPonyPrimitive?(acc) do
      true ->  "Pointer[#{acc}]"
      false -> "NullablePointer[#{acc}]"
    end
  end


  def rationalizeType(%{name: "int", recordType: :FundamentalType}, ""), do: "I32"
  def rationalizeType(%{name: "void", recordType: :FundamentalType}, _acc),                   do: "None"

  def rationalizeType(%{name: "_Bool", recordType: :FundamentalType}, _acc),                  do: "Bool"

  def rationalizeType(%{name: "char", recordType: :FundamentalType}, _acc),                   do: "I8"
  def rationalizeType(%{name: "signed char", recordType: :FundamentalType}, _acc),            do: "I8"
  def rationalizeType(%{name: "unsigned char", recordType: :FundamentalType}, _acc),          do: "U8"

  def rationalizeType(%{name: "short int", recordType: :FundamentalType}, _acc),              do: "I16"
  def rationalizeType(%{name: "short unsigned int", recordType: :FundamentalType}, _acc),     do: "U16"

  def rationalizeType(%{name: "unsigned int", recordType: :FundamentalType}, _acc),           do: "U32"
  def rationalizeType(%{name: "float", recordType: :FundamentalType}, _acc),                  do: "F32"
  def rationalizeType(%{name: "int", recordType: :FundamentalType}, _acc),                    do: "I32"

  def rationalizeType(%{name: "long int", recordType: :FundamentalType}, _acc),               do: "I64"
  def rationalizeType(%{name: "long unsigned int", recordType: :FundamentalType}, _acc),      do: "U64"
  def rationalizeType(%{name: "double", recordType: :FundamentalType}, _acc),                 do: "F64"
  def rationalizeType(%{name: "long long unsigned int", recordType: :FundamentalType}, _acc), do: "U64"
  def rationalizeType(%{name: "long long int", recordType: :FundamentalType}, _acc),          do: "I64"

  def rationalizeType(%{name: "__int128", recordType: :FundamentalType}, _acc),               do: "I128"
  def rationalizeType(%{name: "unsigned __int128", recordType: :FundamentalType}, _acc),      do: "U128"
  def rationalizeType(%{name: "long double", recordType: :FundamentalType}, _acc),            do: "F128"

  def isPonyPrimitive?("None"), do: true
  def isPonyPrimitive?("Bool"), do: true

  def isPonyPrimitive?("I8"), do: true
  def isPonyPrimitive?("I16"), do: true
  def isPonyPrimitive?("I32"), do: true
  def isPonyPrimitive?("I64"), do: true
  def isPonyPrimitive?("I128"), do: true
  def isPonyPrimitive?("ISize"), do: true
  def isPonyPrimitive?("ILong"), do: true

  def isPonyPrimitive?("U8"), do: true
  def isPonyPrimitive?("U16"), do: true
  def isPonyPrimitive?("U32"), do: true
  def isPonyPrimitive?("U64"), do: true
  def isPonyPrimitive?("U128"), do: true
  def isPonyPrimitive?("USize"), do: true
  def isPonyPrimitive?("ULong"), do: true

  def isPonyPrimitive?("F32"), do: true
  def isPonyPrimitive?("F64"), do: true
  def isPonyPrimitive?("F128"), do: true

  def isPonyPrimitive?(_), do: false




  def toPonyPrimitive(name) do
    name
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("")
  end



  defmemo recurseType(_filename, %{id: ""}, acc), do: acc
  defmemo recurseType(filename, x = %{id: _id, name: _name, type: type}, acc) do
    map = typeByID(filename, type)
    recurseType(filename, map, [x|acc])
  end
  #def recurseType(filename, id, acc = [%{recordType: :Typedef}|_]) do
  #  map = typeByID(filename, id)
  #  [map | acc]
  #end



  defmemo typeByID(filename, id) do
    entry = 
    f(filename)
    |> xpath(~x"//*[@id='#{id}']")

    type = Tuple.to_list(entry)
           |> Enum.at(2)
    
    map = xpath(entry, ~x".", id: ~x"./@id"s,
                              name: ~x"./@name"s,
                              type: ~x"./@type"s)

    Map.put(map, :recordType, type)
  end

  def printhelp() do
    IO.puts(
    """
    Usage: ./cast_x_m_l_pony [options]
      --help (-h): Display this help

      ### MANDATORY FIELD
      #    All operations require the output from CastXML to find in the form of and XML file.
      #  This XML file contains the metadata that describes all the C-FFI parameter information
      #  for all the parsed header files all the way down to basic C types.
      --xmlfile (-x): The CastXML file for analysis

      ### OPERATION
      #    There are two basic modes, list and generate.

      ### List mode: --list (-l)
      #    List mode provides human-readable output which is used to explore or prepare your
      #  API spec for export.  We currently support three modes.  With the exception of the
      #  'Header File inventory' mode - it requires a --fileid option.
      #
      #  See the example below.
      
      ##  Header File inventory: Lists the .h files that have been parsed in the provided XML
      #  file. Since we don't want to generate struct and use statements for EVERY dependency
      #  for the library (including glibc) we use the .h files to choose which namespaces
      #  to process.
      #
      #  This command lists the full paths to the header files and the id to refer to them with:
      ./cast_x_m_l_pony --xmlfile pcre2.xml -l

      ##  Struct Inventory: Lists all the structs that are present in the selected .h file.
      ./cast_x_m_l_pony --xmlfile examples/pcre2.xml -l -f f26 -s

      ##  Function Inventory: Lists all the functions that are present in the selected .h file.
      ./cast_x_m_l_pony --xmlfile examples/pcre2.xml -l -f f26 -u

      ### Generation Mode: --generate (-g)
      #    Generation mode produces a (hopefully) syntactically correct pony code template
      #  for your C-FFI needs.  It may even compile sometimes :-)

      ## Struct Generation:
      ./cast_x_m_l_pony --xmlfile examples/pcre2.xml -g -f f26 -u

      ## use (Function) Generation:
      ./cast_x_m_l_pony --xmlfile examples/pcre2.xml -g -f f26 -u


      ### EXAMPLE WORKFLOW

      1. Generate the XML file:
         castxml --castxml-output=1,0,0 -I/nix/store/ny3mzqk9jiyfkmvd5z84mbdg3m16ppjn-pcre2-10.36-dev/include -I/nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include /nix/store/ny3mzqk9jiyfkmvd5z84mbdg3m16ppjn-pcre2-10.36-dev/include/pcre2.h -DPCRE2_CODE_UNIT_WIDTH=8

      2. Ensure your xml file is generated!
         -rw-r--r-- 1 red users 189832 Mar  2 23:51 pcre2.xml

      3. Identify which files are present and you wish to generate for:
         [nix-shell:~/projects/pony/cast_x_m_l_pony]$ ./cast_x_m_l_pony --xmlfile examples/pcre2.xml -l
         f0: <builtin>
         f1: /nix/store/kcihlm9hisj42rd92108h7z93dz7h5a8-CastXML-0.3.4/share/castxml/clang/include/stddef.h
         f2: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/floatn-common.h
         f3: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/stdlib.h
         f4: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/types.h
         f5: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/sys/types.h
         f6: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/types/clock_t.h
         f7: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/types/clockid_t.h
         f8: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/types/time_t.h
         f9: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/types/timer_t.h
         f10: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/stdint-intn.h
         f11: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/byteswap.h
         f12: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/uintn-identity.h
         f13: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/types/__sigset_t.h
         f14: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/types/sigset_t.h
         f15: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/types/struct_timeval.h
         f16: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/types/struct_timespec.h
         f17: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/sys/select.h
         f18: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/thread-shared-types.h
         f19: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/struct_mutex.h
         f20: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/struct_rwlock.h
         f21: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/pthreadtypes.h
         f22: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/alloca.h
         f23: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/bits/stdint-uintn.h
         f24: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/stdint.h
         f25: /nix/store/x1h3zxbr0bif0xr2l44x2pl5hnnc2n0j-glibc-2.32-35-dev/include/inttypes.h
         f26: /nix/store/ny3mzqk9jiyfkmvd5z84mbdg3m16ppjn-pcre2-10.36-dev/include/pcre2.h

      4. Inventory or YOLO?

         [nix-shell:~/projects/pony/cast_x_m_l_pony]$ ./cast_x_m_l_pony --xmlfile examples/pcre2.xml -g -f f26 -u
         use @pcre2_config_8[I32](anon0: U32, anon1: Pointer[None])
         use @pcre2_general_context_copy_8[Pointer[Pcre2RealGeneralContext8]](anon0: Pointer[Pcre2RealGeneralContext8])
         // Not Implemented Yet: use @pcre2_general_context_create_8[Pointer[Pcre2RealGeneralContext8]](anon0: Pointer[FUNCTIONPOINTER], anon1: Pointer[FUNCTIONPOINTER], anon2: Pointer[None])
         use @pcre2_general_context_free_8[None](anon0: Pointer[Pcre2RealGeneralContext8])
         use @pcre2_compile_context_copy_8[Pointer[Pcre2RealCompileContext8]](anon0: Pointer[Pcre2RealCompileContext8])
         use @pcre2_compile_context_create_8[Pointer[Pcre2RealCompileContext8]](anon0: Pointer[Pcre2RealGeneralContext8])
         use @pcre2_compile_context_free_8[None](anon0: Pointer[Pcre2RealCompileContext8])
     <SNIP>
         
         
         [nix-shell:~/projects/pony/cast_x_m_l_pony]$ ./cast_x_m_l_pony --xmlfile examples/pcre2.xml -g -f f26 -s
         primitive Pcre2RealGeneralContext8
         primitive Pcre2RealCompileContext8
         primitive Pcre2RealMatchContext8
         primitive Pcre2RealConvertContext8
         primitive Pcre2RealCode8
         primitive Pcre2RealMatchData8
         primitive Pcre2RealJitStack8
         
         struct Pcre2CalloutBlock8
           var version: U32 = U32(0) // offset: 0
           var callout_number: U32 = U32(0) // offset: 32
           var capture_top: U32 = U32(0) // offset: 64
           var capture_last: U32 = U32(0) // offset: 96
           var offset_vector: Pointer[U64] = Pointer[U64] // offset: 128
           var mark: Pointer[U8] = Pointer[U8] // offset: 192
           var subject: Pointer[U8] = Pointer[U8] // offset: 256
           var subject_length: U64 = U64(0) // offset: 320
           var start_match: U64 = U64(0) // offset: 384
           var current_position: U64 = U64(0) // offset: 448
           var pattern_position: U64 = U64(0) // offset: 512
           var next_item_length: U64 = U64(0) // offset: 576
           var callout_string_offset: U64 = U64(0) // offset: 640
           var callout_string_length: U64 = U64(0) // offset: 704
           var callout_string: Pointer[U8] = Pointer[U8] // offset: 768
           var callout_flags: U32 = U32(0) // offset: 832
      <SNIP>
    """)

  end


end
