--		Copyright 1993-2002 by Daniel R. Grayson
-- rewritten by P. Zinn-Justin 2018

needs "max.m2"
needs "methods.m2"
needs "nets.m2"

Constant = new Type of BasicList
globalAssignment Constant

precedence = method(Dispatch => Thing)
rightPrecedence = method(Dispatch => Thing)
lprec = prec = x -> (getParsing x)#0
rprec = strength2 = x -> (getParsing x)#1
uprec = strength1 = x -> (getParsing x)#2

-- local variables
EmptyName := symbol EmptyName
unit := symbol unit
operator := symbol operator
letters := set characters "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'"
digits := set characters "0123456789"
endsWithIdentifier := s -> (
     c := "";
     n := # s - 1;
     while ( 
	  c = s#n;
	  n > 0 and digits#?c
	  ) do n = n - 1;
     letters#?c)

-----------------------------------------------------------------------------
bigParenthesize = n -> (
     h := height n;
     d := depth n;
     if (h === 2 or h === 1) and (d === 0 or d === 1) then return "(" | n | ")";
     if h+d <= 1 then return "("^-d | n | ")"^-d;
     (stack("/",h+d-2:"|","\\"))^(h-1) | n | (stack("\\",h+d-2:"|","/"))^(h-1)
     )
-----------------------------------------------------------------------------

HeaderType = new Type of Type
HeaderType.synonym = "header type"
HeaderType List := (T,z) -> new T from z
HeaderType Sequence := (T,z) -> new T from z

WrapperType = new Type of Type
WrapperType.synonym = "wrapper type"
WrapperType List := (T,z) -> new T from z
WrapperType Sequence := (T,z) -> new T from z
WrapperType Thing := (T,z) -> new T from {z}

-----------------------------------------------------------------------------

Expression = new Type of BasicList
Expression.synonym = "expression"
expression = method(Dispatch => Thing, TypicalValue => Expression)
expression Expression := identity
Expression#operator = ""

expressionValue = method(Dispatch => Thing)
expressionValue VisibleList := x -> apply(x,expressionValue)
expressionValue Thing := identity

-- with the following line we have no way to distinguish between "hold symbol x" and "hold x" when x has a value:
-- but without it, we have no way to recover a polynomial from its expression, without introducing Holder2 or something like it
expressionValue Symbol := value

value Expression := expressionValue

assert Expression := v -> (
    val := value v;
    if not instance(val, Boolean) then error "assert: expected true or false";
    if not val then error toString("assertion failed:" || net v | " is false")
)

--Holder2 = new WrapperType of Expression			    -- Holder{ printable form, value form }
--Holder2.synonym = "holder"
--Holder = new WrapperType of Holder2			    -- Holder{ printable form, value form }, with printable form === value form
Holder = new WrapperType of Expression
Holder.synonym = "holder"

Describe = new WrapperType of Holder
Describe.synonym = "description"
describe = method(Dispatch => Thing)
describe Thing := x -> new Describe from { unhold expression x }
Describe#{Standard,AfterPrint} = identity -- all this to suppress "o##: class" thing

-- new Holder2 from VisibleList := (H,x) -> (
--      assert( #x === 2 );
--      if instance(x#0,Holder) then {x#0#0,x#1} else {x#0,x#1})
--new Holder from VisibleList := (H,x) -> (
--     assert( #x === 1 );
--     {x#0,x#0})

hold = method(Dispatch => Thing, TypicalValue => Expression)
hold Thing := x -> new Holder from {x}
hold Expression := identity

unhold = method()
unhold Holder := first
-- unhold Holder2 := first
unhold Expression := identity

AssociativeExpression = new Type of Expression
AssociativeExpression.synonym = "associative expression"
--new AssociativeExpression from Sequence := 
--new AssociativeExpression from List := (type,v) -> (
--     toList splice apply(v, 
--	  term -> if class term === type then toSequence term else term
--	  )
--     )

lookupi := x -> (
     r := lookup x;
     if r === null then error "encountered null or missing value";
     r)

toString' = method()
toString'(Function,Thing) := (toString,x) -> toString x
toString Expression := v -> toString'(toString,v)

toExternalFormat = method(Dispatch=>Thing)
toExternalFormat Thing := toExternalString
toExternalFormat Expression := v -> toString'(toExternalFormat,v)
toExternalFormat Symbol := toExternalFormat Sequence := toString

toString'(Function, Expression) := (fmt,v) -> (
     op := class v;
     p := precedence v;
     names := apply(toList v,term -> (
	       if precedence term <= p
	       then "(" | fmt term | ")"
	       else fmt term
	       )
	  );
     if # v === 0 then op#EmptyName
     else demark(op#operator,names)
     )

texMath Holder := v -> texMath v#0
html Holder := v -> html v#0
net Holder := v -> net v#0

--toString'(Function, Holder2) := (fmt,v) -> fmt v#0
toString'(Function, Holder) := (fmt,v) -> fmt v#0

remove(Sequence,expression)

Minus = new WrapperType of Expression		  -- unary minus
Minus.synonym = "minus expression"

Minus#operator = "-"
expressionValue Minus := v -> minus apply(toSequence v,expressionValue)
toString'(Function, Minus) := (fmt,v) -> (
     term := v#0;
     if precedence term > precedence v or class term === Product
     then "-" | fmt term
     else "-(" | fmt term | ")"
     )

Equation = new HeaderType of AssociativeExpression
Equation.synonym = "equation expression"
Equation#operator = "=="
expressionValue Equation := (v) -> (
     v = apply(toSequence v,expressionValue);
     if # v === 2
     then v#0 == v#1
     else if # v <= 1
     then true
     else (
     	  x := v#0;
     	  w := drop(v,1);
     	  all(w,y->x==y)
     	  )
     )
net Equation := v -> (
     n := # v;
     if n === 0 then "Equation{}"
     else if n === 1 then "Equation{" | net v#0 | "}"
     else (
	  p := precedence v;
	  horizontalJoin toList between(" == ", 
	       apply(toList v, e -> if precedence e <= p then bigParenthesize net e else net e))))
toString'(Function, Equation) := (fmt,v) -> (
     n := # v;
     if n === 0 then "Equation{}"
     else if n === 1 then "Equation{" | fmt v#0 | "}"
     else (
	  p := precedence v;
	  demark(" == ", 
	       apply(toList v, e -> if precedence e <= p then ("(", fmt e, ")") else fmt e))))
-----------------------------------------------------------------------------
ZeroExpression = new Type of Holder
ZeroExpression.synonym = "zero expression"
ZERO = new ZeroExpression from {0}
unhold ZeroExpression := identity
-----------------------------------------------------------------------------
OneExpression = new Type of Holder
OneExpression.synonym = "one expression"
ONE = new OneExpression from {1}
unhold OneExpression := identity
-----------------------------------------------------------------------------
Parenthesize = new WrapperType of Holder
Parenthesize.synonym = "possibly parenthesized expression"
unhold Parenthesize := identity
-----------------------------------------------------------------------------
Sum = new WrapperType of AssociativeExpression
Sum.synonym = "sum expression"

Sum#unit = ZERO
Sum#EmptyName = "0"
Sum#operator = "+"
expressionValue Sum := v -> plus apply(toSequence v,expressionValue)

toString'(Function, Sum) := (fmt,v) -> (
     n := # v;
     if n === 0 then "0"
     else (
	  p := precedence v;
	  seps := newClass(MutableList, apply(n+1, i->"+"));
	  seps#0 = seps#n = "";
	  v = apply(n, i -> (
		    if class v#i === Minus 
		    then ( seps#i = "-"; v#i#0 )
		    else v#i ));
	  names := apply(n, i -> (
		    if precedence v#i <= p 
		    then "(" | fmt v#i | ")"
		    else fmt v#i ));
	  concatenate mingle ( seps, names )))

Product = new WrapperType of AssociativeExpression
Product.synonym = "product expression"

Product#unit = ONE
Product#EmptyName = "1"
Product#operator = "*"
expressionValue Product := v -> times apply(toSequence v,expressionValue)

toString'(Function, Product) := (fmt,v) -> (
     n := # v;
     if n === 0 then "1"
     else (
     	  p := precedence v;
	  seps := newClass(MutableList, apply(n+1, i->"*"));
	  seps#0 = seps#n = "";
     	  names := apply(#v,
	       i -> (
		    term := v#i;
	       	    if precedence term <= p then "(" | fmt term | ")"
	       	    else fmt term));
	  concatenate mingle ( seps, names )
	  )
     )

NonAssociativeProduct = new WrapperType of Expression
NonAssociativeProduct.synonym = "nonassociative product expression"

NonAssociativeProduct#unit = ONE
NonAssociativeProduct#EmptyName = "1"
NonAssociativeProduct#operator = "**"
expressionValue NonAssociativeProduct := v -> times apply(toSequence v,expressionValue)

toString'(Function, NonAssociativeProduct) := (fmt,v) -> (
     n := # v;
     if n === 0 then "1"
     else (
     	  p := precedence v;
	  seps := newClass(MutableList, apply(n+1, i->"**"));
	  seps#0 = seps#n = "";
     	  names := apply(#v,
	       i -> (
		    term := v#i;
	       	    if precedence term <= p then "(" | fmt term | ")"
	       	    else fmt term
	       	    )
	       );
	  scan(# v - 1,
	       i -> (
		    if seps#(i+1)!=""
		    and names#(i+1)#?0
		    and letters#?(names#(i+1)#0)
		    and not endsWithIdentifier names#i 
		    then seps#(i+1)=""
		    )
	       );
	  concatenate mingle ( seps, names )
	  )
     )

Divide = new HeaderType of Expression
Divide.synonym = "divide expression"
Divide#operator = "/"
expressionValue Divide := (x) -> (expressionValue x#0) / (expressionValue x#1)
numerator Divide := x -> x#0
denominator Divide := x -> x#1

Power = new HeaderType of Expression
Power.synonym = "power expression"
Power#operator = "^"
expressionValue Power := (x) -> (expressionValue x#0) ^ (expressionValue x#1)

Subscript = new HeaderType of Expression
Subscript.synonym = "subscript expression"
Subscript#operator = "_"
expressionValue Subscript := (x) -> (expressionValue x#0)_(expressionValue x#1)

Superscript = new HeaderType of Expression
Superscript.synonym = "superscript expression"
Superscript#operator = "^"
expressionValue Superscript := (x) -> (expressionValue x#0)^(expressionValue x#1)

toString'(Function, Subscript) := toString'(Function, Superscript) := (fmt,v) -> (
     x := fmt v#0;
     y := fmt v#1;
     p := precedence v;
     if precedence v#0 <  p then x = "(" | x | ")";
     if precedence v#1 <= p then y = "(" | y | ")";
     concatenate(x,(class v)#operator,y))

toString'(Function, Power) := (fmt,v) -> (
     x := v#0;
     y := v#1;
     if y === 1 then fmt x 
     else (
	  x = fmt x;
	  y = fmt y;
	  if precedence v#0 <  prec symbol ^  then x = "(" | x | ")";
	  if precedence v#1 <= prec symbol ^  then y = "(" | y | ")";
	  concatenate(x,(class v)#operator,y)))

-----------------------------------------------------------------------------
RowExpression = new HeaderType of Expression
RowExpression.synonym = "row expression"
net RowExpression := w -> horizontalJoin apply(toList w,net)
html RowExpression := w -> concatenate apply(w,html)
tex RowExpression := w -> concatenate apply(w,tex)
texMath RowExpression := w -> concatenate apply(w,texMath)
toString'(Function, RowExpression) := (fmt,w) -> concatenate apply(w,fmt)
-----------------------------------------------------------------------------
Adjacent = new HeaderType of Expression
Adjacent.synonym = "adjacent expression"
expressionValue Adjacent := x -> (expressionValue x#0) (expressionValue x#1)
-----------------------------------------------------------------------------
prepend0 := (e,x) -> prepend(unhold e, x)
append0 := (x,e) -> append(x, unhold e)
Equation == Equation        := join
Equation == Expression      := append
Equation == Holder          := append0
Expression == Equation      := prepend
Holder     == Equation      := prepend0
Expression == Expression    := Equation => (x,y) -> new Equation from {x,y}
Holder     == Holder        := (x,y) -> new Equation from {unhold x,unhold y}
Expression == Thing         := (x,y) -> x == expression y
Thing == Expression         := (x,y) -> expression x == y
ZeroExpression + Expression := (x,y) -> y
Sum + ZeroExpression     :=
Holder + ZeroExpression     :=
Expression + ZeroExpression := (x,y) -> x
Sum + Sum                   := join
Sum + Expression            := append
Sum + Holder                := append0
Expression + Sum            := prepend
Holder     + Sum            := prepend0
Expression + Expression     := Sum => (x,y) -> new Sum from {x,y}
       - ZeroExpression     := identity
	   - Minus          := x -> expression x#0
           - Expression     := x -> new Minus from {x}
           - Holder         := x -> new Minus from {unhold x}
Expression - Expression     := Sum => (x,y) -> x + Minus y
Thing - Minus               := Sum => (x,y) -> expression x + y#0
Product    * OneExpression  :=
Expression * OneExpression  :=
Holder     * OneExpression  := (x,y) -> x
OneExpression * Expression  := (x,y) -> y
Holder     * ZeroExpression :=
Product    * ZeroExpression :=
Expression * ZeroExpression := (x,y) -> y
ZeroExpression * Holder     :=
ZeroExpression * Expression := (x,y) -> x
Product * Product           := join
Product * Expression        := append
Product * Holder            := append0
Expression * Product        := prepend
Holder     * Product        := prepend0
Expression * Expression := Product => (x,y) -> new Product from {x,y}
Expression * Minus := (x,y) -> -(x * y#0)
Minus * Expression := (x,y) -> -(x#0 * y)
Minus * Minus := (x,y) -> expression x#0 * expression y#0
Expression * Thing      := (x,y) -> x * (expression y)
     Thing * Expression := (x,y) -> (expression x) * y
Holder     ** OneExpression :=
Expression ** OneExpression := (x,y) -> x
OneExpression ** Holder     :=
OneExpression ** Expression := (x,y) -> y
NonAssociativeProduct ** NonAssociativeProduct := join
NonAssociativeProduct ** Expression := append
NonAssociativeProduct ** Holder     := append0
Expression Expression := Adjacent => (x,y) -> new Adjacent from {x,y}
     -- are lists expressions, too???
Expression Thing      := (x,y) -> x (expression y)
     Thing Expression := (x,y) -> (expression x) y
Expression ** NonAssociativeProduct := prepend
Holder     ** NonAssociativeProduct := prepend0
Expression ** Expression := NonAssociativeProduct => (x,y) -> new NonAssociativeProduct from {x,y}
Holder     / OneExpression :=
Expression / OneExpression := (x,y) -> x
Expression / Expression := Divide => (x,y) -> new Divide from {x,y}
not Equation := e -> if #e == 2 then BinaryOperation { symbol !=, e#0, e#1 } else -* UnaryOperation{symbol not, e} *- error ("negation of an equation with ", toString (#e), " parts")
expression ZZ := i -> (
     if i === 0 then ZERO
     else if i === 1 then ONE
     else if i === -1 then new Minus from { ONE }
     else if i < 0 then new Minus from { -i }
     else hold i
     )
Holder     ^ OneExpression :=
Expression ^ OneExpression := (x,y) -> x
Holder     ^ ZeroExpression :=
Expression ^ ZeroExpression := (x,y) -> ONE
ZeroExpression ^ Holder     :=
ZeroExpression ^ Expression := (x,y) -> ZERO
ZeroExpression ^ ZeroExpression := (x,y) -> ONE
Expression ^ Expression := Power => (x,y) -> Power{x,y}
Expression _ Expression := Subscript => (x,y) -> Subscript{x,y}

InfiniteNumber .. InfiniteNumber :=
InfiniteNumber .. ZZ             :=
ZZ             .. InfiniteNumber := (x,y) -> if x < y then (
     error "infinite range requested";
     -- BinaryOperation{symbol ..,x,y}
     ) else ()

InfiniteNumber ..< InfiniteNumber :=
InfiniteNumber ..< ZZ             :=
ZZ             ..< InfiniteNumber := (x,y) -> if x < y then (
     error "infinite range requested";
     -- BinaryOperation{symbol ..<,x,y}
     ) else ()

binaryOperatorFunctions := new HashTable from {
     symbol * => ((x,y) -> x*y),
     symbol + => ((x,y) -> x+y),
     symbol - => ((x,y) -> x-y),
     symbol / => ((x,y) -> x/y),
     symbol // => ((x,y) -> x//y),
     symbol ^ => ((x,y) -> x^y),
     symbol == => ((x,y) -> x==y),
     symbol .. => ((x,y) -> x..y),
     symbol ..< => ((x,y) -> x..<y),
     symbol % => ((x,y) -> x%y),
     symbol @ => ((x,y) -> x@y),
     symbol ==> => ((x,y) -> x==>y),
     symbol ===> => ((x,y) -> x===>y),
     symbol <== => ((x,y) -> x<==y),
     symbol <=== => ((x,y) -> x<===y),
     symbol <==> => ((x,y) -> x<==>y),
     symbol |- => ((x,y) -> x|-y),
     symbol \ => ((x,y) -> x\y),
     symbol @@ => ((x,y) -> x@@y),
     symbol & => ((x,y) -> x&y),
     symbol ? => ((x,y) -> x?y),
     symbol | => ((x,y) -> x|y),
     symbol => => ((x,y) -> x=>y),
     symbol || => ((x,y) -> x||y),
     symbol << => ((x,y) -> x<<y),
     symbol >> => ((x,y) -> x>>y),
     symbol : => ((x,y) -> x:y),
     symbol ++ => ((x,y) -> x++y),
     symbol ** => ((x,y) -> x**y),
     symbol _ => ((x,y) -> x_y),
     symbol SPACE => ((x,y) -> x y),
     symbol != => ((x,y) -> x != y),
     symbol and => ((x,y) -> x and y),
     symbol or => ((x,y) -> x or y),
     symbol xor => ((x,y) -> x xor y),
     symbol ^** => ((x,y) -> x^**y),
     symbol === => ((x,y) -> x === y),
     symbol =!= => ((x,y) -> x =!= y),
     symbol < => ((x,y) -> x < y),
     symbol <= => ((x,y) -> x <= y),
     symbol > => ((x,y) -> x > y),
     symbol >= => ((x,y) -> x >= y),
     symbol ^^ => ((x,y) -> x ^^ y)
     }

expressionBinaryOperators =
{symbol and, symbol <==, symbol ^**, symbol ^, symbol ==>, symbol _,
    symbol ==, symbol ++, symbol <===, symbol <==>, symbol or, symbol xor,
    symbol %, symbol SPACE, symbol &, symbol *, symbol +,
    symbol -, symbol |-, symbol :, symbol !=, symbol |, symbol ..<,
    symbol @@, symbol @, symbol **, symbol .., symbol ^^,
    symbol ||, symbol ===>, symbol /}

scan(expressionBinaryOperators, op -> (
    f := try Expression#(op,Expression,Expression) else installMethod(op,Expression,Expression,(x,y) -> BinaryOperation{op,x,y});
    installMethod(op,Expression,Holder,(x,y) -> f(x,unhold y));
    installMethod(op,Holder,Expression,(x,y) -> f(unhold x,y));
    installMethod(op,Holder,Holder,(x,y) -> f(unhold x,unhold y));
    g := try binaryOperatorFunctions#op else f; -- subtly different
    installMethod(op,Expression,Thing,(x,y) ->  g(x,expression y));
    installMethod(op,Thing,Expression,(x,y) ->  g(expression x,y));
    ))

-----------------------------------------------------------------------------
--expressionValue Holder2 := x -> x#1
expressionValue Holder := x -> expressionValue x#0
expressionValue OneExpression := v -> 1
expressionValue ZeroExpression := v -> 0
-----------------------------------------------------------------------------
SparseVectorExpression = new HeaderType of Expression
SparseVectorExpression.synonym = "sparse vector expression"
expressionValue SparseVectorExpression := x -> notImplemented()
toString'(Function, SparseVectorExpression) := (fmt,v) -> (
     n := v#0;
     w := newClass(MutableList, apply(n,i->"0"));
     scan(v#1,(i,x)->w#i=fmt x);
     w = toList w;
     concatenate("{",between(",",w),"}")
     )
-----------------------------------------------------------------------------
SparseMonomialVectorExpression = new HeaderType of Expression
SparseMonomialVectorExpression.synonym = "sparse monomial vector expression"
-- in these, the basis vectors are treated as variables for printing purposes
expressionValue SparseMonomialVectorExpression := x -> notImplemented()
toString'(Function, SparseMonomialVectorExpression) := (fmt,v) -> toString (
     sum(v#1,(i,m,a) -> 
	  expression a * 
	  expression m * 
	  hold concatenate("<",fmt i,">"))
     )
-----------------------------------------------------------------------------
MatrixExpression = new HeaderType of Expression
MatrixExpression.synonym = "matrix expression"
matrixOpts1 := new OptionTable from {Blocks=>null,Degrees=>null,MutableMatrix=>false};
matrixOpts := m -> ( -- helper function
    (opts,x) := override(matrixOpts1,toSequence m);
    (opts, if #x > 0 and class x#0 =!= List then { x } else toList x) -- because of #1548
    )
expressionValue MatrixExpression := x -> (
    (opts,m) := matrixOpts x;
    m = (if opts.MutableMatrix then mutableMatrix else matrix) applyTable(m,expressionValue);
    -- TODO: keep track of blocks too
    if opts.Degrees === null then m else (
    R := ring m;
    map(R^(-opts.Degrees#0),R^(-opts.Degrees#1),entries m)
    ))
toString'(Function, MatrixExpression) := (fmt,x) -> concatenate(
    (opts,m) := matrixOpts x;
    if opts.MutableMatrix then "mutableMatrix {" else "matrix {",
    between(", ",apply(m,row->("{", between(", ",apply(row,fmt)), "}"))),
    "}" )
-----------------------------------------------------------------------------
VectorExpression = new HeaderType of Expression
VectorExpression.synonym = "vector expression"
expressionValue VectorExpression := x -> vector apply(toList x,expressionValue)
toString'(Function,VectorExpression) := (fmt,v) -> concatenate(
     "vector {",
     between(", ",apply(toList v,fmt)),
     "}" )
-----------------------------------------------------------------------------
Table = new HeaderType of Expression
Table.synonym = "table expression"
expressionValue Table := x -> applyTable(toList x,expressionValue)
toString'(Function, Table) := (fmt,m) -> concatenate(
     "Table {",
     between(", ",apply(toList m,row->("{", between(", ",apply(row,fmt)), "}"))),
     "}" )
-----------------------------------------------------------------------------

spacedOps := set { symbol =>, symbol and, symbol or, symbol xor, symbol ++ }

-- TODO: move this to latex.m2
keywordTexMath = new HashTable from { -- both unary and binary keywords
    symbol |- => "\\vdash ",
    symbol .. => "\\,{.}{.}\\, ",
    symbol ..< => "\\,{.}{.}{<}\\, ",
    symbol <= => "\\le ",
    symbol >= => "\\ge ",
    symbol => => "\\Rightarrow ",
    symbol ==> => "\\Longrightarrow ",
    symbol <== => "\\Longleftarrow ",
    symbol <==> => "\\Longleftrightarrow ",
    symbol ** => "\\otimes ",
    symbol ++ => "\\oplus ",
    symbol != => "\\ne ",
    symbol -> => "\\rightarrow ",
    symbol <- => "\\leftarrow ",
    symbol ===> => "{\\large\\Longrightarrow}",
    symbol <=== => "{\\large\\Longleftarrow}",
    symbol << => "\\ll ",
    symbol >> => "\\gg ",
    symbol ~ => "\\sim ",
    symbol ^** => "^{\\otimes}",
    symbol _ => "\\_ ",
    symbol { => "\\{ ",
    symbol } => "\\} ",
    symbol \ => "\\backslash ",
    symbol \\ => "\\backslash\\backslash ",
    symbol SPACE => "\\texttt{SPACE}",
    symbol # => "\\#",
    symbol #? => "\\#?",
    symbol % => "\\%",
    symbol & => "\\&",
    symbol ^ => "\\wedge",
    symbol ^^ => "\\wedge\\wedge",
    symbol <| => "\\langle",
    symbol |> => "\\rangle"
    }

BinaryOperation = new HeaderType of Expression -- {op,left,right}
BinaryOperation.synonym = "binary operation expression"
expressionValue BinaryOperation := (m) -> (
     if binaryOperatorFunctions#?(m#0) then binaryOperatorFunctions#(m#0) (expressionValue m#1,expressionValue m#2) else m
     )
net BinaryOperation := m -> (
     x := net m#1;
     y := net m#2;
     if rightPrecedence m#1 < lprec m#0 then x = bigParenthesize x;
     if precedence m#2 <= rprec m#0 then y = bigParenthesize y;
     if spacedOps#?(m#0) then horizontalJoin( x, " ", toString m#0, " ", y ) else horizontalJoin( x, toString m#0, y )
     )

texMath BinaryOperation := m -> (
     x := texMath m#1;
     y := texMath m#2;
     if rightPrecedence m#1 < lprec m#0 then x = "\\left(" | x | "\\right)";
     if precedence m#2 <= rprec m#0 then y = "\\left(" | y | "\\right)";
     if spacedOps#?(m#0) then concatenate( x, "\\ ", texMath m#0, "\\ ", y ) else concatenate( x, texMath m#0, y )
     )

toString'(Function, BinaryOperation) := (fmt,m) -> (
     x := fmt m#1;
     y := fmt m#2;
     if rightPrecedence m#1 < lprec m#0 then x = ("(",x,")");
     if precedence m#2 <= rprec m#0 then y = ("(",y,")");
     if spacedOps#?(m#0) then concatenate( x, " ", toString m#0, " ", y ) else concatenate( x, toString m#0, y )
     )

-----------------------------------------------------------------------------
FunctionApplication = new HeaderType of Expression -- {fun,args}
FunctionApplication.synonym = "function application expression"
expressionValue FunctionApplication := (m) -> (expressionValue m#0) (expressionValue m#1)
toString'(Function, Adjacent) := toString'(Function, FunctionApplication) := (fmt,m) -> (
     p := precedence m;
     fun := m#0;
     args := m#1;
     if class args === Sequence
     then if #args === 1
     then concatenate(fmt fun, "(", fmt args#0, ")")  -- f (1:x)
     else concatenate(fmt fun, fmt args)       -- f(x,y) or f(), ...
     else if precedence args > p
     then if precedence fun > p
     then concatenate(fmt fun, if not instance(args,Array) then " ", fmt args)
     else concatenate("(", fmt fun, ")", fmt args)
     else if precedence fun > p
     then concatenate(fmt fun, "(", fmt args, ")")
     else concatenate("(", fmt fun, ")(", fmt args, ")")
     )
net Adjacent := net FunctionApplication := m -> (
     p := precedence m;
     fun := m#0;
     args := m#1;
     netfun := net fun;
     netargs := net args;
     div := instance(fun,Divide);
     pfun := if div then strength1 symbol symbol else precedence fun;
     if precedence args > p
     then if pfun >= p
     then (
	  if instance(args,Array) or div or class netfun === Net and netfun#?0 and width netfun > width netfun#0
	  then horizontalJoin (netfun, netargs)
	  else horizontalJoin (netfun, " ", netargs)
	  )
     else horizontalJoin (bigParenthesize netfun, netargs)
     else if pfun >= p
     then horizontalJoin (netfun, bigParenthesize netargs)
     else horizontalJoin (bigParenthesize netfun, bigParenthesize netargs)
     )
texMath Adjacent := texMath FunctionApplication := m -> if m#0 === sqrt then "\\sqrt{"| texMath m#1 |"}" else (
     p := precedence m;
     fun := m#0;
     args := m#1;
     div := instance(fun,Divide);
     pfun := if div then strength1 symbol symbol else precedence fun;
     -- we can finesse further the amount of space than in net
     -- see also https://tex.stackexchange.com/questions/2607/spacing-around-left-and-right
     if div or instance(args,Array) then sep:="\\mathopen{}"
     else if instance(args,VisibleList) then sep="{}"
     else sep = "\\ ";
     if precedence args > p
     then if pfun >= p
     then concatenate (texMath fun, sep, texMath args)
     else concatenate ("\\left(", texMath fun, "\\right)", texMath args)
     else if pfun >= p
     then concatenate (texMath fun, "\\left(", texMath args, "\\right)")
     else concatenate ("\\left(",texMath fun,"\\right)\\left(", texMath args, "\\right)")
     )
-----------------------------------------------------------------------------

returns = t -> x -> t

	      precedence Sequence := x -> if #x === 1 then prec symbol : else strength1 symbol symbol
     	  precedence Parenthesize := returns 0
	      precedence Equation := returns prec symbol ==
	     precedence HashTable := returns 0		    -- some things might print out as symbols though...
		 precedence Thing := returns 0
		   precedence Sum := returns prec symbol +
	       precedence Product := returns prec symbol *
 precedence NonAssociativeProduct := returns prec symbol **
		 precedence Minus := returns strength1 symbol -
   precedence FunctionApplication := returns prec symbol SPACE
              precedence Adjacent := returns prec symbol SPACE
		precedence Divide := returns prec symbol /
	     precedence Subscript := returns prec symbol _
	   precedence Superscript := returns prec symbol ^
		 precedence Power := x -> if x#1 === 1 then precedence x#0 else prec symbol ^
		    precedence ZZ := x -> if x>=0 then strength1 symbol symbol else prec symbol -
		    precedence RR :=
	      precedence Function :=
	          precedence Type :=
	       precedence Boolean :=
		  precedence List :=
		 precedence Array :=
	  precedence AngleBarList :=
	      precedence Constant :=
		precedence Symbol :=
		   precedence Net :=
		precedence String :=
	    precedence Expression := returns strength1 symbol symbol
	        precedence Holder := x -> precedence x#0
	      precedence Describe := x -> precedence x#0
--	       precedence Holder2 := x -> precedence x#0
       precedence BinaryOperation := x -> lprec x#0
  rightPrecedence BinaryOperation := x -> rprec x#0
            rightPrecedence Thing := precedence
-----------------------------------------------------------------------------
-- printing two dimensional ascii output

nobracket := identity

padto := (s,n) -> (
     k := n - stringlen s;
     if k === 0 then s else (s, k))

-- document { stringlen,
--      TT "stringlen s", "returns the length of the string s.  The argument
--      may also be a sequence or list of strings and symbols, and so
--      on, recursively, in which case the lengths of the various elements
--      are summed.  Additionally, an integer may be used to represent a
--      number of spaces.",
--      SeeAlso => {"String", "concatenate", "#" }
--      }

nopar := x -> (
     -- this is like net Sequence except we omit the parentheses.
     horizontalJoin deepSplice (
	  if #x === 0 then "()"
	  else if #x === 1 then ("1 : (", net x#0, ")")
	  else (toSequence between(",",apply(x,net)))))

nopars := x -> if class x === Sequence then nopar x else net x

net Subscript := x -> (
     n := nopars x#1;
     if precedence x#0 < prec symbol ^
     then horizontalJoin( bigParenthesize net x#0, n^-(height n) )
     else net x#0 | n^-(height n)
     )

net Superscript := x -> if x#1 === moduleZERO then "0" else (
     n := net x#1;
     if precedence x#0 < prec symbol ^
     then horizontalJoin( bigParenthesize net x#0, n^(1+depth n))
     else net x#0 | n^(1+depth n)
     )

expectExponent = n -> if height n < 2 then n = (stack( 2 - height n : "", n))^1 else n

net Power := v -> (
     x := v#0;
     y := v#1;
     if y === 1 or y === ONE then net x
     else (
     	  nety := net y;
	  nety = nety ^ (1 + depth nety);
	  if class x === Subscript then (
	       t := stack(nety,"",nopars x#1);
	       horizontalJoin (
		    if precedence x < prec symbol ^
		    then ( bigParenthesize expectExponent net x#0, t)
		    else (                 net x#0, t)
		    )
	       )
	  else (
	       horizontalJoin (
		    if precedence x <= prec symbol ^
		    then ( bigParenthesize expectExponent net x, nety)
		    else (            	   net x, nety)
		    )
	       )
	  )
     )
net Sum := v -> (
     n := # v;
     if n === 0 then "0"
     else (
	  p := precedence v;
	  seps := newClass(MutableList, apply(n+1, i->" + "));
	  seps#0 = seps#n = "";
	  v = apply(n, i -> (
		    if class v#i === Minus
		    then (
			 seps#i = if i == 0 then "- " else " - ";
			 v#i#0)
		    else v#i));
	  horizontalJoin splice mingle(seps,
	       apply(n, i ->
		    if precedence v#i <= p
		    then bigParenthesize net v#i
		    else      	   	 net v#i))))

isNumber = method(TypicalValue => Boolean)
isNumber Thing := i -> false
isNumber RR :=
isNumber QQ := -- QQ never appears in an expression...
isNumber ZZ := i -> true
isNumber Holder := i -> isNumber i#0
isNumber Divide := d -> isNumber d#0 and isNumber d#1 -- .. so we take care of it this way

startsWithSymbol = method(TypicalValue => Boolean)
startsWithSymbol Thing := i -> false
startsWithSymbol Symbol := i -> true
startsWithSymbol Product :=
startsWithSymbol Subscript :=
startsWithSymbol Power :=

startsWithSymbol Holder := i -> startsWithSymbol i#0
-- startsWithSymbol Holder2 := i -> startsWithSymbol i#0

net Product := v -> (
     n := # v;
     if n === 0 then "1"
     else (
     	  p := precedence v;
	  seps := newClass(MutableList, splice {"", n-1 : "*", ""});
	  if n>1 and isNumber v#0 and startsWithSymbol v#1 then seps#1 = "";
     	  boxes := apply(#v,
	       i -> (
		    term := v#i;
		    nterm := net term;
	       	    if precedence term <= p and class term =!= Divide then (
			 seps#i = seps#(i+1) = "";
			 nterm = bigParenthesize nterm;
			 );
		    if class term === Power
		    and not (term#1 === 1 or term#1 === ONE)
		    or class term === Subscript then (
			 seps#(i+1) = "";
			 );
	       	    nterm));
	  horizontalJoin splice mingle (seps, boxes)
	  )
     )
net NonAssociativeProduct := v -> (
     n := # v;
     if n === 0 then "1"
     else (
     	  p := precedence v;
	  seps := newClass(MutableList, apply(n+1, i -> "**"));
	  seps#0 = seps#n = "";
     	  boxes := apply(#v,
	       i -> (
		    term := v#i;
	       	    if precedence term <= p then bigParenthesize net term
	       	    else net term
	       	    )
	       );
	  horizontalJoin splice mingle (seps, boxes)
	  )
     )

net Minus := x -> (
     term := x#0;
     horizontalJoin if precedence term <= precedence x	    -- note that precedence(Minus{...}) and precedence(Sum{...}) are equal
     then ("-", bigParenthesize net term)
     else (
	  term = net term;
	  h := height term - 1;
	  (if term#?h and term#h#?0 and term#h#0 === "-" then "- " else "-", term)))

net Divide := x -> (
     top := net x#0;
     bot := net x#1;
     wtop := width top;
     wbot := width bot;
     w := max(wtop,wbot);
     if instance(x#0,Divide) or instance(x#1,Divide) then w = w+2;
     itop := (w-wtop+1)//2;
     if itop != 0 then top = spaces itop | top;
     ibot := (w-wbot+1)//2;
     if ibot != 0 then bot = spaces ibot | bot;
     top = top || dashes w;
     top = top ^ (depth top);
     top || bot)
net SparseVectorExpression := v -> (
     if # v === 0
     then "0"
     else net sum(v#1,(i,r) -> (
	       expression r *
	       hold concatenate("<",toString i,">")
	       )
	  )
     )
net SparseMonomialVectorExpression := v -> (
     if # v === 0
     then "0"
     else (
	  net sum(v#1,(i,m,a) ->
	       expression a *
	       expression m *
	       hold concatenate("<",toString i,">"))
	  )
     )

net Table := x -> netList (toList x, HorizontalSpace=>2, VerticalSpace => 1, BaseRow => 0, Boxes => false, Alignment => Center)

compactMatrixForm=true; -- governs net MatrixExpression
matrixDisplayOptions := hashTable { true => new OptionTable from { HorizontalSpace => 1, VerticalSpace => 0, BaseRow => 0, Alignment => Left },
                                   false => new OptionTable from { HorizontalSpace => 2, VerticalSpace => 1, BaseRow => 0, Alignment => Center } }

toCompactString := method(Dispatch => Thing)
toCompactParen = x -> if precedence x < prec symbol * then "(" | toCompactString x | ")" else toCompactString x
toCompactString Thing := toString
toCompactString RingElement := x -> toString raw x
-- toCompactString can also handle e.g. factored expressions
toCompactString Product := x -> if #x === 0 then "1" else concatenate apply(toList x,toCompactParen)
toCompactString Sum := x -> if #x === 0 then "0" else concatenate apply(#x,i->
    if i===0 or class x#i === Minus then toCompactString x#i else { "+", toCompactString x#i })
toCompactString Minus := x -> "-" | toCompactParen x#0
toCompactString Power := x -> if x#1 === 1 or x#1 === ONE then toCompactString x#0 else (
    a:=toCompactParen x#0;
    b:=toCompactString x#1;
    if #a =!= 1 then a|"^"|b else a|b
    )
toCompactString Divide := x -> toCompactParen x#0 | "/" | toCompactParen x#1

net MatrixExpression := x -> (
    (opts,m) := matrixOpts x;
    blk := opts.Blocks =!= null; -- whether to display blocks
    if all(m,r->all(r,i->class i===ZeroExpression)) then return "0";
    net1 := if compactMatrixForm then toCompactString else net;
    vbox0 := if opts.Degrees === null then 0 else 1;
    (hbox,vbox) := if blk then (drop(accumulate(plus,0,opts.Blocks#0),-1),prepend(vbox0,accumulate(plus,vbox0,opts.Blocks#1))) else (false,{vbox0,vbox0+#m#0});
    m = if opts.Degrees =!= null then apply(#m,i->apply(prepend(opts.Degrees#0#i,m#i),net1)) else applyTable(m,net1);
    netList(m,Boxes=>{hbox,vbox},matrixDisplayOptions#compactMatrixForm)
    )

--html MatrixExpression := x -> html TABLE toList x

net VectorExpression := x -> (
    if all(x,i->class i===ZeroExpression) then "0"
     else (
	 x=apply(toList x,y->{(if compactMatrixForm then toCompactString else net)y});
	netList(x,Boxes=>{false,{0,1}},HorizontalSpace=>1,VerticalSpace=>if compactMatrixForm then 0 else 1,BaseRow=>0,Alignment=>Center)
     ))
--html VectorExpression := x -> html TABLE apply(toList x,y->{y})

-----------------------------------------------------------------------------
-- tex stuff

texMath Expression := v -> (
     op := class v;
     p := precedence v;
     names := apply(toList v,term -> (
	       if precedence term <= p
	       then ("{\\left(", texMath term, "\\right)}")
	       else ("{", texMath term, "}") ) );
     if # v === 0 then (
	  if op#?EmptyName then op#EmptyName
	  else error("no method for texMath ", op)
	  )
     else (
	  if op#?operator then demark(op#operator,names)
	  else error("no method for texMath ", op)
	  )
     )

--html Thing := toString
-*
html Expression := v -> (
     op := class v;
     p := precedence v;
     names := apply(toList v,term -> (
	       if precedence term <= p
	       then ("(", html term, ")")
	       else html term));
     if # v === 0
     then (
	  if op#?EmptyName then op#EmptyName
	  else error("no method for html ", op)
	  )
     else (
	  if op#?operator then demark(op#operator,names)
	  else error("no method for html ", op)
	  )
     )
*-
texMath Minus := v -> (
     term := v#0;
     if precedence term <= precedence v
     then "-\\left(" | texMath term | "\\right)"
     else "-" | texMath term
     )

-*
html Minus := v -> (
     term := v#0;
     if precedence term < precedence v
     then "-(" | html term | ")"
     else "-" | html term
     )
*-

texMath Divide := x -> "\\frac{" | texMath x#0 | "}{" | texMath x#1 | "}"

-*
html Divide := x -> (
     p := precedence x;
     a := html x#0;
     b := html x#1;
     if precedence x#0 <= p then a = "(" | a | ")";
     if precedence x#1 <= p then b = "(" | b | ")";
     a | " / " | b)
*-

texMath Sum := v -> (
     n := # v;
     if n === 0 then "0"
     else (
	  p := precedence v;
	  seps := apply(toList(1..n-1), i -> if class v#i === Minus then "" else "+");
	  names := apply(n, i -> (
		    if precedence v#i <= p and class v#i =!= Minus
		    then "\\left(" | texMath v#i | "\\right)"
		    else texMath v#i ));
	  concatenate mingle ( names, seps )))

-*
html Sum := v -> (
     n := # v;
     if n === 0 then "0"
     else (
	  p := precedence v;
	  seps := newClass(MutableList, apply(n+1, i->"+"));
	  seps#0 = seps#n = "";
	  v = apply(n, i -> (
		    if class v#i === Minus
		    then ( seps#i = "-"; v#i#0 )
		    else v#i ));
	  names := apply(n, i -> (
		    if precedence v#i <= p
		    then "(" | html v#i | ")"
		    else html v#i ));
	  concatenate (
	       mingle(seps, names)
	       )))
*-

texMath Product := v -> (
    n := # v;
    if n === 0 then "1"
    else (
	v = apply(v, x -> if class x === Power and (x#1 === 1 or x#1 === ONE) then x#0 else x);
	p := precedence v;
	nums := apply(v, x -> isNumber x or (class x === Power and isNumber x#0));
	precs := apply(v, x -> precedence x <= p);
	seps := apply (n-1, i-> if nums#(i+1) then "\\times "
	    else if class v#i =!= Power and class v#i =!= Subscript and not precs#i and not precs#(i+1) then
	    if nums#i or class v#i === Symbol then "\\," else "\\ "
	    else "");
	boxes := apply(n, i -> (
		if precs#i and class v#i =!= Divide
		then "\\left(" | texMath v#i | "\\right)"
		else texMath v#i
		)
	    );
	concatenate splice mingle (boxes,seps)
	)
    )
-*
html Product := v -> (
     n := # v;
     if n === 0 then "1"
     else if n === 1 then html v#0
     else (
     	  p := precedence v;
     	  concatenate apply(#v,
	       i -> (
		    term := v#i;
	       	    if precedence term <= p
		    then "(" | html term | ")"
	       	    else html term
	       	    )
	       )
	  )
     )
*-

texMath Power := v -> if v#1 === 1 or v#1 === ONE then texMath v#0 else (
    p := precedence v;
    x := texMath v#0;
    y := texMath v#1;
    if precedence v#0 <  p then x = "\\left(" | x | "\\right)";
    concatenate(x,"^{",y,"}") -- no braces around x
    )

texMath Superscript := v -> if v#1 === moduleZERO then "0" else (
    p := precedence v;
    x := texMath v#0;
    y := texMath v#1;
    if precedence v#0 <  p then x = "\\left(" | x | "\\right)";
    concatenate(x,"^{",y,"}") -- no braces around x
    )

texMath Subscript := v -> (
     p := precedence v;
     x := texMath v#0;
     y := if class v#1 === Sequence then demark(",", apply(v#1,texMath)) else texMath v#1; -- no () for sequences
     if precedence v#0 <  p or class v#0 === Subscript then x = "\\left(" | x | "\\right)"; -- precedence or double subscript
     concatenate(x,"_{",y,"}") -- no braces around x
     )

-*
html Superscript := v -> (
     p := precedence v;
     x := html v#0;
     y := html v#1;
     if precedence v#0 <  p then x = "(" | x | ")";
     concatenate(x,"<sup>",y,"</sup>"))

html Power := v -> (
     if v#1 === 1 then html v#0
     else (
	  p := precedence v;
	  x := html v#0;
	  y := html v#1;
	  if precedence v#0 <  p then x = "(" | x | ")";
	  concatenate(x,"<sup>",y,"</sup>")))

html Subscript := v -> (
     p := precedence v;
     x := html v#0;
     y := html v#1;
     if precedence v#0 <  p then x = "(" | x | ")";
     concatenate(x,"<sub>",y,"</sub>"))
*-

texMath SparseVectorExpression := v -> (
     n := v#0;
     w := newClass(MutableList, apply(n,i->"0"));
     scan(v#1,(i,x)->w#i=texMath x);
     concatenate("\\begin{pmatrix}", between("\\\\ ",w),"\\end{pmatrix}")
     )

texMath SparseMonomialVectorExpression := v -> (
     texMath sum(v#1,(i,m,a) ->
	  expression a *
	  expression m *
	  hold concatenate("<",toString i,">"))
     )

texMath Table := m -> (
    if m#?0 then concatenate(
	"\\begin{array}{", #m#0: "c", "}", newline,
	between(///\\/// | newline, apply(toList m, row -> between("&",apply(row,texMath)))),
	newline, "\\end{array}")
    else "{}"
    )

texMath MatrixExpression := x -> (
    (opts,m) := matrixOpts x;
    if all(m,r->all(r,i->class i===ZeroExpression)) then return "0";
    blk := opts.Blocks =!= null; -- whether to display blocks
    if blk then ( j := 0; h := 0; );
    m = applyTable(m,texMath);
    concatenate(
	if opts.Degrees =!= null then (
	    degs := apply(opts.Degrees#0,texMath);
	    "\\begin{array}{l}",
	    apply(#m, i -> concatenate(degs#i,"\\vphantom{",m#i, "}", if i<#m-1 then "\\\\")),
	    "\\end{array}"
	    ),
	"\\left(",
	"\\!\\begin{array}{",
	if blk then demark("|",apply(opts.Blocks#1,i->i:"c")) else #m#0:"c",
	"}",
	newline,
	apply(#m, i -> concatenate(
		if opts.Degrees =!= null then "\\vphantom{"| degs#i | "}",
		 between("&",m#i),
		 if i<#m-1 then "\\\\", -- sadly, LaTeX *requires* no final \\
		 newline,
		 if blk then (j=j+1; if h<#opts.Blocks#0-1 and j == opts.Blocks#0#h then (j=0; h=h+1; "\\hline\n"))
		 )),
	"\\end{array}\\!",
	"\\right)"
	)
)

texMath VectorExpression := v -> (
    concatenate(
	"\\left(",
	"\\!\\begin{array}{c}",
	newline,
	between(///\\///,apply(toList v,texMath)),
	"\\end{array}\\!",
	"\\right)"
	)
    )

-----------------------------------------------------------------------------
print =  x -> (
    c := class x;
    while not c#?{topLevelMode,print} do (
	if c === Thing then (<< net x << endl; return); -- default
	c = parent c;
	);
    c#{topLevelMode,print} x
    )
-----------------------------------------------------------------------------

File << Thing := File => (o,x) -> printString(o,net x)

o := () -> concatenate(interpreterDepth:"o")

Thing#{Standard,AfterPrint} = x -> (
     << endl;				  -- double space
     << o() << lineNumber;
     y := class x;
     << " : " << y;
     << endl;
     )

-* TODO: add an option to re-enable these two
Type#{Standard,AfterPrint} = x -> (
     << endl;				  -- double space
     << o() << lineNumber;
     y := class x;
     << " : " << y << ", with ancestors: ";
     << concatenate between_" < " drop(toString \ ancestors y, 1);
     << endl;
     )

Function#{Standard,AfterPrint} = x -> (
     Thing#{Standard,AfterPrint} x;
     briefDocumentation x;
     )
*-

Expression#{Standard,AfterPrint} = x -> (
     << endl;				  -- double space
     << o() << lineNumber << " : " << Expression << " of class " << class x << endl;
     )

-----------------------------------------------------------------------------

expression VisibleList := v -> new Holder from { apply(v, expression) }
expression Thing :=
expression Symbol :=
expression Function :=
expression Boolean :=
expression Type := x -> new Holder from { x }

-----------------------------------------------------------------------------

Nothing#{Standard,AfterPrint} = identity
ZZ#{Standard,AfterPrint} = identity
Boolean#{Standard,AfterPrint} = identity

FilePosition = new Type of BasicList
FilePosition.synonym = "file position"
toString FilePosition :=
net FilePosition := i -> concatenate(i#0,":",toString i#1,":",toString i#2)

-- extra stuff
expression Option := z -> BinaryOperation { symbol =>, unhold expression z#0, unhold expression z#1 }
net Option := net @@ expression
texMath Option := x -> texMath expression x
toString Option := toString @@ expression

SheafExpression = new WrapperType of Expression;
toString'(Function, SheafExpression) := (fmt,x) -> toString'(fmt,new FunctionApplication from { sheaf, x#0 })
net SheafExpression := x -> net x#0
texMath SheafExpression := x -> texMath x#0
expressionValue SheafExpression := x -> sheaf expressionValue x#0

moduleZERO = new ZeroExpression from { 0, Module }

-- little used at the moment. note that one can't have a symbol <---
MapExpression = new HeaderType of Expression;
toString'(Function, MapExpression) := (fmt,x) -> toString'(fmt,new FunctionApplication from { map, toSequence x })
lineOnTop := (s) -> concatenate(width s : "-") || s
net MapExpression := x-> if #x>2 then horizontalJoin(net x#0, " <--",
		    lineOnTop net x#2,
		    "-- ", net x#1) else net x#0 | " <--- " | net x#1
texMath MapExpression := x -> texMath x#0 | "\\," | (if #x>2 then "\\xleftarrow{" | texMath x#2 | "}" else "\\longleftarrow ") | "\\," | texMath x#1
expressionValue MapExpression := x -> map toSequence apply(x,expressionValue)

-- moved from set.m2 because of loadsequence order
expression Set := x -> Adjacent {set, expression (sortByName keys x)}
toString Set := toString @@ expression
net Set := net @@ expression
texMath Set := x -> texMath expression x

-- shortening expressions
Dots = new Type of Symbol
cdots=new Dots from symbol cdots
ddots=new Dots from symbol ddots
vdots=new Dots from symbol vdots
ldots=new Dots from symbol ldots
texMath Dots := x -> "\\" | simpleToString x -- note that \vdots has bad spacing in ordinary LaTeX
toString Dots := x -> "..."
net Dots := x -> if x === vdots then "."||"."||"." else if x === ddots then ".  "||" . "||"  ." else "..."

shortLength := 8
-- used e.g. in chaincomplexes.m2
Short = new WrapperType of Holder
unhold Short := identity
short = method(Dispatch => Thing, TypicalValue => Short)
short Thing := x -> short expression x
short Holder := x -> Short unhold x
expressionValue Short := x -> error "can't evaluate a shortened expression"
short MatrixExpression :=
short Table := x -> Short (
    (opts,m) := matrixOpts x;
    shortRow := row -> apply(if #row>shortLength then { first row, cdots, last row } else row,short);
    new class x from
	apply(if #m>shortLength then {first m,if #m#0>shortLength then {vdots,ddots,vdots} else toList(#m#0:vdots),last m}
	    else m,shortRow)
    )
short VisibleList :=
short Expression := x -> Short { apply(if #x>shortLength then new class x from {
	first x,
	if instance(x,VectorExpression) or instance(x,VerticalList) then vdots else if instance(x,VisibleList) then ldots else cdots,
	last x
	}
    else x,short) }
short Minus := identity
short BinaryOperation := b -> Short BinaryOperation {b#0,short b#1,short b#2}
short Power := p -> Short Power {short p#0,p#1}
short String := s -> Short if #s > shortLength then first s | "..." | last s else s
short Net := n -> Short if #n > shortLength then stack {short first n,".",".",".",short last n} else (stack apply(unstack n,short))^(height n-1)

-- Local Variables:
-- compile-command: "make -C $M2BUILDDIR/Macaulay2/m2 "
-- End:
