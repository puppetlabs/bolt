<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:svg="http://www.w3.org/2000/svg">
  
  <!-- Logical containers -->
  
  <xsl:template match="*[contains(@class,' pr-d/syntaxdiagram ')]" priority="500">
    <svg width="200" height="100">
      <xsl:apply-templates/>
    </svg>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/fragment ')]" priority="2">
    <div>
     <a><xsl:attribute name="name"><xsl:value-of select="title"/></xsl:attribute> </a>
     <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/synblk ')]" priority="2">
    <!--span-->
      <xsl:call-template name="apply-for-phrases"/>
    <!--/span-->
  </xsl:template>
  
  <!-- titles for logical containers -->
  
  <xsl:template match="*[contains(@class,' pr-d/syntaxdiagram ')]/*[contains(@class,' topic/title ')]">
    <text style="font-size: 16; font-family: Arial; font-weight: bold; stroke:none; fill:blue;">
    <xsl:value-of select="."/>
    </text>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' pr-d/fragment ')]/*[contains(@class,' topic/title ')]" priority="2">
    <text style="font-size: 12; font-family: Arial; font-weight: bold; stroke:none; fill:blue;">
    <xsl:value-of select="."/>
    </text>
  </xsl:template>
  
  <!-- Basically, we want to hide his content. -->
  <xsl:template match="*[contains(@class,' pr-d/repsep ')]" priority="2"/>
  
  <xsl:template match="*[contains(@class,' pr-d/kwd ')]" priority="2">
  <text style="font-size: 11; font-family: Arial; font-weight: bold; stroke:none; fill:blue;">
    <xsl:if test="parent::*[contains(@class, ' pr-d/groupchoice ')]"><xsl:if test="count(preceding-sibling::*)!=0"> | </xsl:if></xsl:if>
    <xsl:if test="@importance='optional'"> [</xsl:if>
    <xsl:choose>
      <xsl:when test="@importance='default'"><u><xsl:value-of select="."/></u></xsl:when>
      <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
    </xsl:choose>
    <xsl:if test="@importance='optional'">] </xsl:if>
  </text>
    <xsl:call-template name="drawpath"/>
  </xsl:template>
  
</xsl:stylesheet>