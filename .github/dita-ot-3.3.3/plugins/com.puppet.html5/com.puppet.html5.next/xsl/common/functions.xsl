<?xml version="1.0" encoding="utf-8"?>

<!-- This file is part of the DITA Open Toolkit project.
     See the accompanying license.txt file for applicable licenses.-->
<!-- (c) Copyright IBM Corp. 2004, 2005 All Rights Reserved. -->

<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
  exclude-result-prefixes="xs dita-ot">

  <!-- ID -->

  <xsl:function name="dita-ot:get-element-id" as="xs:string?">
    <xsl:param name="href"/>
    <!-- DOC-3432: When getting IDs, replace underscores with dashes because Drupal rewrites header IDs. -->
    <xsl:variable name="fragment" select="replace(substring-after($href, '#'), '_', '-')" as="xs:string"/>
    <xsl:if test="contains($fragment, '/')">
      <xsl:value-of select="substring-after($fragment, '/')"/>
    </xsl:if>
  </xsl:function>

  <xsl:function name="dita-ot:get-topic-id" as="xs:string?">
    <xsl:param name="href"/>
    <!-- DOC-3432: When getting IDs, replace underscores with dashes because Drupal rewrites header IDs. -->
    <xsl:variable name="fragment" select="replace(substring-after($href, '#'), '_', '-')" as="xs:string"/>
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

</xsl:stylesheet>
