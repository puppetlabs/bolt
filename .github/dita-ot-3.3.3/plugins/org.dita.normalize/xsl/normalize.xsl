<?xml version="1.0" encoding="UTF-8"?>
<!--
  This file is part of the DITA Open Toolkit project.
  See the accompanying license.txt file for applicable licenses.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ditaarch="http://dita.oasis-open.org/architecture/2005/"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                exclude-result-prefixes="xs ditaarch dita-ot xsi"
                version="2.0">
  
  <xsl:param name="output.dir.uri"/>
  
  <xsl:template match="/">
    <xsl:for-each select="job/files/file[@format = ('dita', 'ditamap')]">
      <xsl:variable name="output.uri" select="concat($output.dir.uri, @uri)"/>
      <xsl:message select="$output.uri"/>
      <xsl:for-each select="document(@uri, .)">
        <xsl:choose>
          <xsl:when test="*/@xsi:noNamespaceSchemaLocation">
            <xsl:result-document href="{$output.uri}">
              <xsl:apply-templates/>
            </xsl:result-document>
          </xsl:when>
          <xsl:otherwise>
            <xsl:result-document href="{$output.uri}"
                                 doctype-public="{dita-ot:get-doctype-public(.)}"
                                 doctype-system="{dita-ot:get-doctype-system(.)}">
              <xsl:apply-templates/>
            </xsl:result-document>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:function name="dita-ot:get-doctype-public">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:choose>
      <xsl:when test="$doc/processing-instruction('doctype-public')">
        <xsl:value-of select="$doc/processing-instruction('doctype-public')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>-//OASIS//DTD DITA </xsl:text>
        <xsl:choose>
          <xsl:when test="$doc/dita">Composite</xsl:when>
          <xsl:when test="$doc/*[contains(@class, ' bookmap/bookmap ')]">BookMap</xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="upper-case(substring(name($doc/*), 1, 1))"/>
            <xsl:value-of select="lower-case(substring(name($doc/*), 2))"/>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:text>//EN</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="dita-ot:get-doctype-system">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:choose>
      <xsl:when test="$doc/processing-instruction('doctype-system')">
        <xsl:value-of select="$doc/processing-instruction('doctype-system')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="name($doc/*)"/>
        <xsl:text>.dtd</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:template match="@class | @domains | @xtrf | @xtrc | @ditaarch:DITAArchVersion"
                priority="10"/>
  
  <xsl:template match="processing-instruction('workdir') |
                       processing-instruction('workdir-uri') |
                       processing-instruction('path2project') |
                       processing-instruction('path2project-uri') |
                       processing-instruction('ditaot') |
                       processing-instruction('doctype-public') |
                       processing-instruction('doctype-system') |
                       @dita-ot:* |
                       @mapclass"
                priority="10"/>

  <xsl:template match="*[number(@ditaarch:DITAArchVersion) &lt; 1.3]/@cascade"/>

  <xsl:template match="*[@class]" priority="-5">
    <xsl:element name="{tokenize(tokenize(normalize-space(@class), '\s+')[last()], '/')[last()]}"
                 namespace="{namespace-uri()}">
      <xsl:apply-templates select="node() | @*"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="*" priority="-10">
    <xsl:element name="{name()}" namespace="{namespace-uri()}">
      <xsl:apply-templates select="node() | @*"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="node() | @*" priority="-15">
    <xsl:copy>
      <xsl:apply-templates select="node() | @*"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>