<?xml version="1.0" encoding="utf-8"?>

<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
  exclude-result-prefixes="xs dita-ot">

  <!-- href -->

  <xsl:function name="dita-ot:resolve-href-path" as="xs:anyURI">
    <xsl:param name="href" as="attribute(href)"/>

    <xsl:variable name="source" as="xs:anyURI" select="base-uri($href)"/>

    <xsl:sequence select="
        if (starts-with($href, '#'))
      then $source
      else resolve-uri(tokenize($href, '#')[1], $source)
    "/>
  </xsl:function>

  <xsl:function name="dita-ot:retrieve-href-target" as="node()?">
    <xsl:param name="href" as="attribute(href)"/>

    <xsl:variable name="doc" as="document-node()"
      select="doc(dita-ot:resolve-href-path($href))"/>

    <xsl:sequence select="
        if (dita-ot:has-element-id($href))
      then $doc/key('id', dita-ot:get-element-id($href))
           [dita-ot:get-closest-topic(.)/@id eq dita-ot:get-topic-id($href)]
      else if (dita-ot:has-topic-id($href) and not(dita-ot:has-element-id($href)))
           then $doc/key('id', dita-ot:get-topic-id($href))
           else $doc
    "/>
  </xsl:function>

  <!-- ID -->

  <xsl:function name="dita-ot:has-topic-id" as="xs:boolean">
    <xsl:param name="href"/>
    <xsl:sequence select="contains($href, '#')"/>
  </xsl:function>

  <xsl:function name="dita-ot:get-element-id" as="xs:string?">
    <xsl:param name="href"/>
    <xsl:variable name="fragment" select="substring-after($href, '#')" as="xs:string"/>
    <xsl:if test="contains($fragment, '/')">
      <xsl:value-of select="substring-after($fragment, '/')"/>
    </xsl:if>
  </xsl:function>

  <xsl:function name="dita-ot:has-element-id" as="xs:boolean">
    <xsl:param name="href"/>
    <xsl:sequence select="contains(substring-after($href, '#'), '/')"/>
  </xsl:function>

  <xsl:function name="dita-ot:get-topic-id" as="xs:string?">
    <xsl:param name="href"/>
    <xsl:variable name="fragment" select="substring-after($href, '#')" as="xs:string"/>
    <xsl:if test="string-length($fragment) gt 0">
      <xsl:choose>
        <xsl:when test="contains($fragment, '/')">
          <xsl:value-of select="substring-before($fragment, '/')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$fragment"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:function>

  <!-- language -->

  <xsl:function name="dita-ot:get-current-language" as="xs:string">
    <xsl:param name="ctx" as="node()"/>

    <xsl:sequence select="
      lower-case(($ctx/ancestor-or-self::*[@xml:lang][1]/@xml:lang, $DEFAULTLANG)[1])
    "/>
  </xsl:function>

  <xsl:function name="dita-ot:get-iso-language-code" as="xs:string">
    <xsl:param name="lang" as="xs:string"/>
    <xsl:sequence select="tokenize($lang, '-')[1]"/>
  </xsl:function>

  <xsl:function name="dita-ot:get-language-codes" as="xs:string*">
    <xsl:param name="lang" as="xs:string"/>
    <xsl:sequence select="$lang, dita-ot:get-iso-language-code($lang)"/>
  </xsl:function>

  <xsl:function name="dita-ot:get-first-topic-language" as="xs:string">
    <!-- $ctx should contain the root element.
         If toot element is <dita>, check first topic. Otherwise, root element. Otherwise, default. -->
    <xsl:param name="ctx" as="node()"/>
    <xsl:sequence select="
      lower-case(($ctx/self::dita/*[1]/@xml:lang, $ctx/@xml:lang, $DEFAULTLANG)[1])
    "/>
  </xsl:function>

  <!-- URI -->

  <xsl:function name="dita-ot:normalize-uri" as="xs:string">
    <xsl:param name="uri" as="xs:string"/>
    <xsl:call-template name="dita-ot:normalize-uri">
      <xsl:with-param name="src" select="tokenize($uri, '/')"/>
    </xsl:call-template>
  </xsl:function>

  <xsl:function name="dita-ot:get-variable" as="node()*">
    <xsl:param name="ctx" as="node()"/>
    <xsl:param name="id" as="xs:string"/>
    <xsl:param name="params" as="node()*"/>

    <xsl:call-template name="findString">
      <xsl:with-param name="ctx" select="$ctx" tunnel="yes"/>
      <xsl:with-param name="id" select="$id"/>
      <xsl:with-param name="params" select="$params"/>
      <xsl:with-param name="ancestorlang"
        select="dita-ot:get-language-codes(dita-ot:get-current-language($ctx))"/>
      <xsl:with-param name="defaultlang" select="dita-ot:get-language-codes($DEFAULTLANG)"/>
    </xsl:call-template>
  </xsl:function>

  <xsl:function name="dita-ot:get-variable" as="node()*">
    <xsl:param name="ctx" as="node()"/>
    <xsl:param name="id" as="xs:string"/>

    <xsl:sequence select="dita-ot:get-variable($ctx, $id, ())"/>
  </xsl:function>

</xsl:stylesheet>
