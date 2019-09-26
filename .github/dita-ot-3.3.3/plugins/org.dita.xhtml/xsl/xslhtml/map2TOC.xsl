<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0" 
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:html="http://www.w3.org/1999/xhtml"
        exclude-result-prefixes="html">

<!-- stylesheet imports -->
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/mapwalker.xsl"/>

<xsl:template match="*[contains(@class,' map/map ')]">
  <xsl:apply-templates select="." mode="toctop"/>
</xsl:template>

<xsl:template match="*[contains(@class,' map/topicref ')]" mode="process">
  <xsl:param name="infile"/>
  <xsl:param name="outroot"/>
  <xsl:param name="outfile"/>
  <xsl:param name="nodeID"/>
  <xsl:param name="isFirst"/>
  <xsl:variable name="subtopicNodes"
      select="*[contains(@class,' map/topicref ')]"/>
  <xsl:variable name="title">
    <xsl:apply-templates select="." mode="title">
      <xsl:with-param name="isFirst" select="$isFirst"/>
      <xsl:with-param name="infile"  select="$infile"/>
      <xsl:with-param name="nodeID"  select="$nodeID"/>
      <xsl:with-param name="outfile" select="$outfile"/>
    </xsl:apply-templates>
  </xsl:variable>
  <xsl:apply-templates select="." mode="tocentry">
    <xsl:with-param name="infile"        select="$infile"/>
    <xsl:with-param name="outroot"       select="$outroot"/>
    <xsl:with-param name="outfile"       select="$outfile"/>
    <xsl:with-param name="nodeID"        select="$nodeID"/>
    <xsl:with-param name="isFirst"       select="$isFirst"/>
    <xsl:with-param name="subtopicNodes" select="$subtopicNodes"/>
    <xsl:with-param name="title"         select="$title"/>
  </xsl:apply-templates>
</xsl:template>

<!-- required overrides -->
<xsl:template match="*[contains(@class,' map/map ')]" mode="toctop">
  <xsl:message terminate="yes">
    <xsl:text>no toctop rule for map</xsl:text>
  </xsl:message>
</xsl:template>

<xsl:template match="*[contains(@class,' map/topicref ')]" mode="tocentry">
  <xsl:param name="infile"/>
  <xsl:param name="outroot"/>
  <xsl:param name="outfile"/>
  <xsl:param name="nodeID"/>
  <xsl:param name="isFirst"/>
  <xsl:param name="subtopicNodes"/>
  <xsl:param name="title"/>
  <xsl:message terminate="yes">
    <xsl:text>no tocentry rule for topicref</xsl:text>
  </xsl:message>
</xsl:template>

<!-- topic title -->
<xsl:template match="*[contains(@class,' map/topicref ')]" mode="title">
  <xsl:param name="isFirst"/>
  <xsl:param name="infile"/>
  <xsl:param name="nodeID"/>
  <xsl:param name="outfile"/>
  <xsl:choose>
    <xsl:when test="*[contains(@class,'- map/topicmeta ')]/*[contains(@class, '- topic/navtitle ')]">
      <xsl:value-of select="*[contains(@class,'- map/topicmeta ')]/*[contains(@class, '- topic/navtitle ')]"/>
    </xsl:when>
    <xsl:when test="not(*[contains(@class,'- map/topicmeta ')]/*[contains(@class, '- topic/navtitle ')]) and @navtitle"><xsl:value-of select="@navtitle"/></xsl:when>
  <xsl:otherwise>
    <xsl:message>
      <xsl:text>neither title nor href</xsl:text>
    </xsl:message>
    <xsl:text></xsl:text>
  </xsl:otherwise>
  </xsl:choose>
</xsl:template>


</xsl:stylesheet>
