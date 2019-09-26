<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2018 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:svg="http://www.w3.org/2000/svg"
                exclude-result-prefixes="dita-ot svg">

  <xsl:template match="*[contains(@class, ' svg-d/svgref ')]" name="topic.svg-d.svgref">
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <img>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setid"/>
      <xsl:apply-templates select="@href"/>
    </img>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    <!-- image name for review -->
    <xsl:if test="$ARTLBL = 'yes'"> [<xsl:value-of select="@href"/>] </xsl:if>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' svg-d/svgref ')]/@href">
    <xsl:attribute name="src" select="."/>
  </xsl:template>
    
  <xsl:template match="*[contains(@class, ' svg-d/svg-container ')]" name="topic.svg-d.svg-container">
    <xsl:call-template name="setaname"/>
    <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="svg:svg">
    <xsl:apply-templates select="." mode="dita-ot:svg-prefix"/>
  </xsl:template>

  <xsl:template match="svg:*" mode="dita-ot:svg-prefix" priority="10">
    <xsl:element name="{local-name()}" namespace="http://www.w3.org/2000/svg">
      <xsl:apply-templates select="@* | node()" mode="dita-ot:svg-prefix"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="@* | node()" mode="dita-ot:svg-prefix">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="dita-ot:svg-prefix"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
