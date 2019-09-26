<?xml version="1.0"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2010 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
  exclude-result-prefixes="dita-ot"
  >

  <!-- DEFAULT RULE: FOR EVERY ELEMENT, ONLY PROCESS TEXT CONTENT -->
  <xsl:template match="*" mode="dita-ot:text-only">
    <xsl:apply-templates select="text()|*|processing-instruction()" mode="dita-ot:text-only"/>
  </xsl:template>

  <xsl:template match="text()" mode="dita-ot:text-only">
    <xsl:value-of select="."/>
  </xsl:template>
  
  <!-- add "'" for q -->
  <xsl:template match="*[contains(@class,' topic/q ')]" mode="dita-ot:text-only">
    <xsl:call-template name="getVariable">
      <xsl:with-param name="id" select="'OpenQuote'"/>
    </xsl:call-template>
    <xsl:apply-templates mode="dita-ot:text-only"/>
    <xsl:call-template name="getVariable">
      <xsl:with-param name="id" select="'CloseQuote'"/>
    </xsl:call-template>
  </xsl:template>
  

  <xsl:template match="processing-instruction()" mode="dita-ot:text-only"/>

  <!-- ELEMENTS THAT SHOULD BE DROPPED FROM DEFAULT TEXT-ONLY RENDITIONS -->
  <xsl:template match="*[contains(@class,' topic/indexterm ')]" mode="dita-ot:text-only"/>
  <xsl:template match="*[contains(@class,' topic/draft-comment ')]" mode="dita-ot:text-only"/>
  <xsl:template match="*[contains(@class,' topic/required-cleanup ')]" mode="dita-ot:text-only"/>
  <xsl:template match="*[contains(@class,' topic/data ')]" mode="dita-ot:text-only"/>
  <xsl:template match="*[contains(@class,' topic/data-about ')]" mode="dita-ot:text-only"/>
  <xsl:template match="*[contains(@class,' topic/unknown ')]" mode="dita-ot:text-only"/>
  <xsl:template match="*[contains(@class,' topic/foreign ')]" mode="dita-ot:text-only"/>

  <!-- EXCEPTIONS -->
  <xsl:template match="*[contains(@class,' topic/image ')]" mode="dita-ot:text-only">
    <xsl:choose>
      <xsl:when test="*[contains(@class,' topic/alt ')]"><xsl:apply-templates mode="dita-ot:text-only"/></xsl:when>
      <xsl:when test="@alt"><xsl:value-of select="@alt"/></xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- Footnote as text-only: should just create the number in parens -->
  <xsl:template match="*[contains(@class,' topic/fn ')]" mode="dita-ot:text-only">
    <xsl:variable name="fnid"><xsl:number from="/" level="any"/></xsl:variable>
    <xsl:choose>
      <xsl:when test="@callout">(<xsl:value-of select="@callout"/>)</xsl:when>
      <xsl:otherwise>(<xsl:value-of select="$fnid"/>)</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*[contains(@class,' topic/xref ')]" mode="dita-ot:text-only">
    <xsl:apply-templates select="node()[not(contains(@class,' topic/desc '))]" mode="dita-ot:text-only"/>
  </xsl:template>


  <xsl:template match="*[contains(@class,' topic/boolean ')]" mode="dita-ot:text-only">
    <xsl:value-of select="name()"/><xsl:text>: </xsl:text><xsl:value-of select="@state"/>
  </xsl:template>
  <xsl:template match="*[contains(@class,' topic/state ')]" mode="dita-ot:text-only">
    <xsl:value-of select="name()"/><xsl:text>: </xsl:text><xsl:value-of select="@name"/><xsl:text>=</xsl:text><xsl:value-of select="@value"/>
  </xsl:template>
  
</xsl:stylesheet>
