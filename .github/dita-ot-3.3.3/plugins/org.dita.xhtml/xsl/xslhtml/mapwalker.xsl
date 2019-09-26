<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<!-- write technique adapted from Norman Walsh's DocBook XSLT
     first instance technique adapted from Jeni Tennison and Steve Muench -->

<xsl:stylesheet version="2.0" 
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!-- stylesheet imports -->

<xsl:key name="topicref"
         match="*[contains(@class, ' map/topicref ')]"
         use="@href"/>

<xsl:template match="/">
  <xsl:apply-templates select="*[contains(@class,' map/map ')]"/>
</xsl:template>

<xsl:template match="*[contains(@class,' map/map ')]">
  <xsl:apply-templates select="*[contains(@class,' map/topicref ')]"/>
</xsl:template>

<xsl:template match="*[contains(@class,' map/topicref ')]">
  <xsl:param name="infile" select="@href"/>
  <xsl:param name="outroot">
    <xsl:choose>
    <xsl:when test="contains($infile, '.xml')">
      <xsl:value-of select="substring-before($infile, '.xml')"/>
    </xsl:when>
    <xsl:when test="contains($infile, '.dita')">
      <xsl:value-of select="substring-before($infile, '.dita')"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$infile"/>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:param>
  <xsl:param name="outfile">
    <xsl:choose>
    <xsl:when test="contains($infile, '.xml') or contains($infile, '.dita')">
      <xsl:value-of select="concat($outroot, $OUTEXT)"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$infile"/>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:param>  
  <xsl:param name="nodeID" select="generate-id(.)"/>
  <xsl:param name="isFirstFile">
    <xsl:choose>
    <xsl:when test="$infile and $infile!=''">
      <xsl:value-of
        select="$nodeID = generate-id(key('topicref', $infile)[1])"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="true()"/>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:param>
  <xsl:param name="isFirst" select="string($isFirstFile)='true'"/>
  <xsl:apply-templates select="." mode="process">
    <xsl:with-param name="infile"  select="@href"/>
    <xsl:with-param name="outroot" select="$outroot"/>
    <xsl:with-param name="outfile" select="$outfile"/>
    <xsl:with-param name="nodeID"  select="$nodeID"/>
    <xsl:with-param name="isFirst" select="$isFirst"/>
  </xsl:apply-templates>
</xsl:template>

<!-- required overrides -->
<xsl:template match="*[contains(@class,' map/topicref ')]" mode="process">
  <xsl:param name="infile"/>
  <xsl:param name="outroot"/>
  <xsl:param name="outfile"/>
  <xsl:param name="nodeID"/>
  <xsl:param name="isFirst"/>
  <xsl:message terminate="yes">
    <xsl:text>no process rule for topicref</xsl:text>
  </xsl:message>
</xsl:template>

</xsl:stylesheet>
