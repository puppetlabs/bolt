<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ditaarch="http://dita.oasis-open.org/architecture/2005/"
                xmlns:x="https://github.com/jelovirt/dita-ot-markdown"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="xs x">

  <xsl:import href="classpath:///hdita2dita-common.xsl"/>
  <xsl:import href="classpath:///specialize.xsl"/>

  <xsl:output indent="yes"></xsl:output>

  <xsl:template match="/">
    <xsl:variable name="dita" as="element()">
      <xsl:apply-templates select="html"/>
    </xsl:variable>
    <xsl:apply-templates select="$dita" mode="dispatch"/>
  </xsl:template>

  <xsl:template match="html">
    <xsl:choose>
      <xsl:when test="count(body/article) gt 1">
        <dita>
          <xsl:attribute name="ditaarch:DITAArchVersion">1.3</xsl:attribute>
          <xsl:apply-templates select="@* | node()"/>
        </dita>        
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="body"/>        
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="article">
    <xsl:variable name="name" select="'topic'"/>
    <xsl:element name="{$name}">
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="." mode="topic"/>
      <xsl:attribute name="ditaarch:DITAArchVersion">1.3</xsl:attribute>
      <xsl:apply-templates select="ancestor::*/@xml:lang"/>
      <xsl:apply-templates select="@*"/>
      <xsl:variable name="h" select="(h1, h2, h3, h4, h5, h6)[1]" as="element()?"/>
      <xsl:choose>
        <xsl:when test="@id">
          <xsl:apply-templates select="@id"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="x:get-id(.)"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="$h"/>
      <body class="- topic/body ">
        <xsl:apply-templates select="* except ($h, article)"/>
      </body>
      <xsl:apply-templates select="article"/>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>
