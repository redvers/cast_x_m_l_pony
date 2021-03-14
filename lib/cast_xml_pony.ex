import SweetXml
defmodule CastXMLPony do
  use Memoize
  def main(args) do
    opts = [xmlfile: :string, structs: :boolean, uses: :boolean, list: :boolean, fileid: :string, generate: :boolean]
    aliases = [x: :xmlfile, s: :structs, u: :uses, l: :list, f: :fileid, g: :generate]
    options = [strict: opts, aliases: aliases]
    {opts,_} = OptionParser.parse!(args, options)

    optmap = Enum.into(opts, Map.new)

    if (Map.get(optmap, :list, false) and (Map.get(optmap, :fileid, false) == false)), do: listfiles(optmap.xmlfile)
    if (Map.get(optmap, :list, false) and is_binary(Map.get(optmap, :fileid, false))) do
      if (Map.get(optmap, :structs, false)) do
        IO.puts("Structs:")
        structs(optmap.xmlfile, optmap.fileid)
        |> Enum.map(&IO.puts/1)
      end
      if (Map.get(optmap, :uses, false)) do
        IO.puts("Functions:")
        functions(optmap.xmlfile, optmap.fileid)
        |> Enum.map(&IO.puts/1)
      end
    end

    if (Map.get(optmap, :generate, false) and is_binary(Map.get(optmap, :fileid, false))) do
      if (Map.get(optmap, :structs, false)) do
        structs(optmap.xmlfile, optmap.fileid)
        |> Enum.map(&(useStructReal(optmap.xmlfile, &1)))
        |> Enum.join("\n\n")
        |> IO.puts
      end
      if (Map.get(optmap, :uses, false)) do
        functions(optmap.xmlfile, optmap.fileid)
        |> Enum.map(&(useFunction(optmap.xmlfile, &1)))
        |> Enum.join("\n")
        |> IO.puts
      end
    end

  end

  def listfiles(filename) do
    f(filename)
    |> xpath(~x"/CastXML/File"l, name: ~x"./@name"s, id: ~x"./@id"s)
    |> Enum.map(fn(%{id: id, name: name}) -> "#{id}: #{name}" end)
    |> Enum.map(&IO.puts/1)
  end


  def f(filename) do
    File.read!(filename)
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
      "" -> "primitive #{toPonyPrimitive(smap.name)}"
      x -> fields =
           String.split(x, " ") 
           |> Enum.map(&(fieldMap(filename, &1)))
           |> Enum.map(fn(%{name: name, ponytype: ponytype, offset: offset}) -> "  var #{name}: #{ponytype} = #{ponydefault(ponytype)} // offset: #{offset}" end)
           |> Enum.join("\n")

      """
      struct #{toPonyPrimitive(smap.name)}
      #{fields}
      """
    
    end
  end

  def ponydefault(x = <<"Pointer"::utf8, _rest::binary>>), do: x
  def ponydefault(x), do: "#{x}(0)"


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
    "use @#{name}[#{recurseType(filename, returns)}](#{makeargs(args,filename)})"
  end


  def makeargs([], _filename), do: ""
  def makeargs(listofargs, filename) do
    len = Enum.count(listofargs)

    Range.new(0,len-1)
    |> Enum.map(&({&1, recurseType(filename, Enum.at(listofargs, &1).type)}))
    |> Enum.map(fn({x,type}) -> "anon#{x}: #{type}" end)
    |> Enum.join(", ")
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

  def rationalizeType(%{name: _name, recordType: :Field}, acc), do: acc
  def rationalizeType(%{name: _name, recordType: :Enumeration}, _acc), do: "I32"
  def rationalizeType(%{name: _name, recordType: :FunctionType}, _acc), do: "FUNCTIONPOINTER"
  def rationalizeType(%{name: name, recordType: :Struct}, acc), do: toPonyPrimitive(name) <> acc
  def rationalizeType(%{name: _name, recordType: :PointerType}, acc), do: "Pointer[#{acc}]"
  def rationalizeType(%{name: _name, recordType: :ArrayType}, acc), do: "Pointer[#{acc}]"

  def rationalizeType(%{name: "int", recordType: :FundamentalType}, ""), do: "I32"
  def rationalizeType(%{name: "void"}, _acc),                   do: "None"

  def rationalizeType(%{name: "_Bool"}, _acc),                  do: "Bool"

  def rationalizeType(%{name: "char"}, _acc),                   do: "I8"
  def rationalizeType(%{name: "signed char"}, _acc),            do: "I8"
  def rationalizeType(%{name: "unsigned char"}, _acc),          do: "U8"

  def rationalizeType(%{name: "short int"}, _acc),              do: "I16"
  def rationalizeType(%{name: "short unsigned int"}, _acc),     do: "U16"

  def rationalizeType(%{name: "unsigned int"}, _acc),           do: "U32"
  def rationalizeType(%{name: "float"}, _acc),                  do: "F32"
  def rationalizeType(%{name: "int"}, _acc),                    do: "I32"

  def rationalizeType(%{name: "long int"}, _acc),               do: "I64"
  def rationalizeType(%{name: "long unsigned int"}, _acc),      do: "U64"
  def rationalizeType(%{name: "double"}, _acc),                 do: "F64"
  def rationalizeType(%{name: "long long unsigned int"}, _acc), do: "U64"
  def rationalizeType(%{name: "long long int"}, _acc),          do: "I64"

  def rationalizeType(%{name: "__int128"}, _acc),               do: "I128"
  def rationalizeType(%{name: "unsigned __int128"}, _acc),      do: "U128"
  def rationalizeType(%{name: "long double"}, _acc),            do: "F128"



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


end
