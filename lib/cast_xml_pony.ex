import SweetXml
defmodule CastXMLPony do
  def main() do
    f("pcre2.xml")
  end
  def f(filename) do
    File.read!(filename)
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


  def makeargs([], filename), do: ""
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

  def recurseType(filename, id) do
    recurseType(filename, typeByID(filename, id), [])
    |> rationalizeType()
  end

  def rationalizeType(list) do
    list
    |> Enum.reject(fn(%{recordType: type}) -> type in [:ElaboratedType, :Typedef, :CvQualifiedType] end)
    |> Enum.reduce("", &rationalizeType/2)
  end

  def rationalizeType(%{name: name, recordType: :Enumeration}, acc), do: "I32"
  def rationalizeType(%{name: name, recordType: :FunctionType}, acc), do: "FUNCTIONPOINTER"
  def rationalizeType(%{name: name, recordType: :Struct}, acc), do: toPonyPrimitive(name) <> acc
  def rationalizeType(%{name: name, recordType: :PointerType}, acc), do: "Pointer[#{acc}]"

  def rationalizeType(%{name: "int", recordType: :FundamentalType}, ""), do: "I32"
  def rationalizeType(%{name: "void"}, acc),                   do: "None"

  def rationalizeType(%{name: "_Bool"}, acc),                  do: "Bool"

  def rationalizeType(%{name: "char"}, acc),                   do: "I8"
  def rationalizeType(%{name: "signed char"}, acc),            do: "I8"
  def rationalizeType(%{name: "unsigned char"}, acc),          do: "U8"

  def rationalizeType(%{name: "short int"}, acc),              do: "I16"
  def rationalizeType(%{name: "short unsigned int"}, acc),     do: "U16"

  def rationalizeType(%{name: "unsigned int"}, acc),           do: "U32"
  def rationalizeType(%{name: "float"}, acc),                  do: "F32"
  def rationalizeType(%{name: "int"}, acc),                    do: "I32"

  def rationalizeType(%{name: "long int"}, acc),               do: "I64"
  def rationalizeType(%{name: "long unsigned int"}, acc),      do: "U64"
  def rationalizeType(%{name: "double"}, acc),                 do: "F64"
  def rationalizeType(%{name: "long long unsigned int"}, acc), do: "U64"
  def rationalizeType(%{name: "long long int"}, acc),          do: "I64"

  def rationalizeType(%{name: "__int128"}, acc),               do: "I128"
  def rationalizeType(%{name: "unsigned __int128"}, acc),      do: "U128"
  def rationalizeType(%{name: "long double"}, acc),            do: "F128"



  def toPonyPrimitive(name) do
    name
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("")
  end



  def recurseType(filename, %{id: ""}, acc), do: acc
  def recurseType(filename, x = %{id: id, name: name, type: type}, acc) do
    map = typeByID(filename, type)
    recurseType(filename, map, [x|acc])
  end
  #def recurseType(filename, id, acc = [%{recordType: :Typedef}|_]) do
  #  map = typeByID(filename, id)
  #  [map | acc]
  #end



  def typeByID(filename, id) do
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
