<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:x="https://github.com/jelovirt/dita-ot-markdown"
                exclude-result-prefixes="xs x"
                version="2.0">

  <xsl:variable name="x:is-block-classes" as="xs:string*"
    select="
      (
      ' topic/body ',
      ' topic/bodydiv ',
      ' topic/shortdesc ',
      ' topic/abstract ',
      ' topic/title ',
      ' task/info ',
      ' topic/p ',
      ' topic/pre ',
      ' topic/note ',
      ' topic/fig ',
      ' topic/figgroup ',
      ' topic/dl ',
      ' topic/sl ',
      ' topic/ol ',
      ' topic/ul ',
      ' topic/li ',
      ' topic/sli ',
      ' topic/lines ',
      ' topic/itemgroup ',
      ' topic/section ',
      ' topic/sectiondiv ',
      ' topic/div ',
      ' topic/lq ',
      ' topic/table ',
      ' topic/entry ',
      ' topic/simpletable ',
      ' topic/stentry ',
      ' topic/example ',
      ' task/cmd ')"/>

  <xsl:function name="x:is-block" as="xs:boolean">
    <xsl:param name="element" as="node()"/>
    <xsl:variable name="class" select="string($element/@class)" as="xs:string"/>
    <xsl:sequence
      select="
        some $c in $x:is-block-classes
          satisfies contains($class, $c) or
          (contains($class, ' topic/image ') and $element/@placement = 'break')"
    />
  </xsl:function>

</xsl:stylesheet>
