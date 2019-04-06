//
//  Parser+Node.swift
//  TypeCheckedAST
//
//  Created by Yuta Saito on 2019/04/05.
//

import Curry

func parseNode() -> Parser<RawNode> {
    let node = (curry(RawNode.init)
        <^> keyword()
        <*> skipSpaces() *> parseNodeValue()
        <*> many(
            skipSpaces() *> parseAttributeOrNode() <* skipSpaces()
        )
    )
    return token("(") *> node <* skipSpaces() <* token(")")
}

func parseNodeValue() -> Parser<String?> {
    return Optional.some <^> stringLiteral() <|> Parser.pure(nil)
}

func parseAttributeOrNode() -> Parser<AttributeOrNode> {
    return (AttributeOrNode.attribute <^> parseAttribute())
       <|> (AttributeOrNode.node <^> parseNode())
}

func parseAttribute() -> Parser<Attribute> {
    return choice(
        [
            Attribute.range <^> token("range=") *> parseRange(),
            Attribute.type <^> token("type=") *> parseTypeName(),
            Attribute.location <^> token("location=") *> parsePoint(),
            const(Attribute.nothrow) <^> token("nothrow"),
            curry(Attribute.decl) <^> token("decl=") *> parseDecl(),
            Attribute.__unknown <^> parseUnknown(),
        ]
    )
}

func parseUnknown() -> Parser<UnknownAttribute> {
    let value = (String.init(describing:) <^> parseRange())
        <|> (String.init(describing:) <^> parseTypeName())
        <|> (String.init(describing:) <^> parsePoint())
        <|> (String.init(describing:) <^> parseElements())
        <|> (String.init(describing:) <^> parseDecl())
        <|> satisfyString(predicate: {
            return $0 != " " && $0 != "(" && $0 != ")" && $0 != "\n"
        })
    return curry(UnknownAttribute.init)
        <^> keyword()
        <*> (Optional.some <^> (token("=") *> value) <|> .pure(nil))
}

let join4: (String, String, String, String) -> String = { $0 + $1 + $2 + $3 }
let join3: (String, String, String) -> String = { $0 + $1 + $2 }
let join2: (String, String) -> String = { $0 + $1 }

func declSignature() -> Parser<String> {
    // foo(arg:)
    let funcSig = curry(join4) <^> keyword()
        <*> token("(") <*> keyword() <*> token(")")
    // (file)
    let fileSig = curry(join3) <^> token("(")
        <*> keyword() <*> token(")")
    let sig = funcSig <|> fileSig <|> keyword()
    func rec() -> Parser<[String]> {
        return cons
            <^> (curry(join2) <^> token(".") <*> sig)
            <*> (rec() <|> Parser.pure([]))
    }

    return curry({ $0.joined() }) <^> (cons <^> keyword() <*> rec())
}

func parseDecl() -> Parser<Decl> {
    let signatures = many1(skipSpaces() *> declSignature() <* skipSpaces())
    return curry(Decl.init)
        <^> (curry({ $0.joined(separator: " ") }) <^> signatures) <* skipSpaces()
        <*> (Optional.some <^> parseDeclSubstitution() <|> Parser.pure(nil))
}

func parseDeclSubstitution() -> Parser<String> {
    // FIXME
    func parenRec() -> Parser<String> {
        let parenBox = curry(join4)
            <^> Parser.pure(" ")
            <*> token("(")
            <*> satisfyString(predicate: { $0 != "(" && $0 != ")" })
            <*> (curry(join2) <^> (parenRec() <|> .pure("")) <*> token(")"))
        return { $0.joined() } <^> many(
            skipSpaces() *> parenBox <* skipSpaces()
        )
    }
    return curry(join3) <^> token("[with") <*> parenRec() <*> token("]")
}

func parseRange() -> Parser<Range> {
    return token("[") *>
        (
            curry(Range.init)
                <^> parsePoint() <* token(" - ")
                <*> parsePoint()
        )
        <* token("]")
}

func parsePoint() -> Parser<Range.Point> {
    return curry(Range.Point.init)
        <^> satisfyString(predicate: { $0 != ":" && $0 != "\n" && $0 != " " })
        <*> token(":") *> number()
        <*> token(":") *> number()
}


func parseTypeName() -> Parser<String> {
    let validString = satisfyString(predicate: { $0 != "'" })
    return char("\'") *> validString <* char("\'")
}

func parseElements() -> Parser<[String]> {
    return char("[") *>
        ({ [$0] } <^> satisfyString(predicate: { $0 != "]" }))
        <* char("]")
}
