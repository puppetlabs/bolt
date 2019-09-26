<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2006 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<!-- Second step in the DITA to text transform. This takes an intermediate
     format, and converts it to text output. The text style is determined by
     the OUTFORMAT parameter. Currently supported values are plaintext, troff,
     and nroff (troff and nroff match at the moment). 

     The first step creates an intermediate format that uses only a few elements.
     It has a root <dita> element, and everything else fits in to these elements:
      <section> : used for <section> and <example>. This can nest any of the following elements.
      <sectiontitle> : used for the titles of <section> and <example>. This will nest the <text> element.
      <block> : all other block-like elements. The reason section does not use <block> 
                is that it maps well to troff-style sections that use the .SH macro
                for highlighting and indenting. This can nest any number of <block> 
                or <text> elements. Attributes set lead-in text (such as list item numbers 
                that must appear before the list item text), as well as indent values.
                Other attributes are described below.
      <text> : all text nodes and phrases. This can include text or additional <text> elements.

     Text will be wrapped, with the width determined by the LINELENGTH parameter. 
     Formatters such as troff may reflow the text as needed. Line breaks should only
     be forced in pre-formatted text, or between blocks.
     
     -->

<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                >

<xsl:import href="step2-base.xsl"/>

<xsl:output method="text"
            encoding="UTF-8"
            indent="no"
            omit-xml-declaration = "yes"
/>

<xsl:template name="force-newline">
  <xsl:value-of select="$newline"/>.br<xsl:value-of select="$newline"/>
</xsl:template>
<xsl:template name="force-two-newlines">
  <xsl:value-of select="$newline"/>.sp 2<xsl:value-of select="$newline"/>
</xsl:template>

<!-- Set the default justification -->
<xsl:template name="set-default-justification">
  <xsl:choose>
    <xsl:when test="/dita/@dir='rtl'">
      <xsl:value-of select="$newline"/>.ad r<xsl:value-of select="$newline"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$newline"/>.ad l<xsl:value-of select="$newline"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
<!-- Set the default line length. Tables are 72, so set it to 72. -->
<xsl:template name="set-default-linelength">
  <xsl:value-of select="$newline"/>.ll 72<xsl:value-of select="$newline"/>
</xsl:template>

<!-- Turn on centering -->
<xsl:template name="start-centering">
  <!-- Centers the next 1000 lines, or until centering is turned off -->
  <xsl:value-of select="$newline"/>.ce 1000<xsl:value-of select="$newline"/>
</xsl:template>
<!-- Turn on centering -->
<xsl:template name="stop-centering">
  <xsl:value-of select="$newline"/>.ce 0<xsl:value-of select="$newline"/>
</xsl:template>

<!-- root rule -->
<xsl:template match="/">
  <xsl:call-template name="set-default-justification"/>
  <xsl:call-template name="set-default-linelength"/>
  <xsl:apply-templates select="*[1]"/>
</xsl:template>


<!-- Based on step1, section titles should come first in the section. If this is
     a *ROFF format, use the .SH macro to get roff's section-like formatting. -->
<xsl:template match="sectiontitle">
  <xsl:if test="preceding-sibling::*">
    <xsl:call-template name="force-two-newlines"/>
  </xsl:if>
  <xsl:value-of select="$newline"/>.SH "<xsl:apply-templates select="*[1]"/>"<xsl:value-of select="$newline"/>
  <xsl:call-template name="start-bold"/>
  <xsl:apply-templates select="*[1]">
    <xsl:with-param name="current-style" select="'bold'"/>
  </xsl:apply-templates>
  <xsl:call-template name="start-normal"/>
  <!-- Do not process following siblings: those come through from section -->
</xsl:template>

<!-- The following three functions will switch the current style to the
     proper formatting. For plain text, nothing is generated. -->
<xsl:template name="start-bold">
  <xsl:text>\fB</xsl:text>  
</xsl:template>
<xsl:template name="start-italics">
  <xsl:text>\fI</xsl:text>
</xsl:template>
<xsl:template name="start-underlined">
  <!-- No underlined in basic troff, use italic -->
  <xsl:text>\fI</xsl:text>
</xsl:template>
<!-- Default is already tt for these formats, so use normal font -->
<xsl:template name="start-tt">
  <xsl:text>\fR</xsl:text>
</xsl:template>
<xsl:template name="start-normal">
  <xsl:text>\fR</xsl:text>
</xsl:template>
  
<!-- This is called to process the contents of <text> elements. It will set
   the correct style if needed, and process children, and then return the
   style to normal. -->
<xsl:template name="format-text">
  <xsl:param name="current-style" select="'normal'"/>
  <xsl:choose>
    <xsl:when test="not(@style)"><xsl:apply-templates/></xsl:when>
    <xsl:when test="@style='bold'">
      <xsl:call-template name="start-bold"/>
      <xsl:apply-templates>
        <xsl:with-param name="current-style" select="@style"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:when test="@style='italics'">
      <xsl:call-template name="start-italics"/>
      <xsl:apply-templates>
        <xsl:with-param name="current-style" select="@style"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:when test="@style='underlined'">
      <xsl:call-template name="start-underlined"/>
      <xsl:apply-templates>
        <xsl:with-param name="current-style" select="@style"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:when test="@style='tt'">
      <xsl:call-template name="start-tt"/>
      <xsl:apply-templates>
        <xsl:with-param name="current-style" select="@style"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
  </xsl:choose>
  <!-- If there was a style, return to original style -->
  <xsl:if test="@style='bold' or @style='italics' or @style='underlined' or @style='tt'">
    <xsl:choose>
      <xsl:when test="$current-style='bold'"><xsl:call-template name="start-bold"/></xsl:when>
      <xsl:when test="$current-style='italics'"><xsl:call-template name="start-italics"/></xsl:when>
      <xsl:when test="$current-style='underlined'"><xsl:call-template name="start-underlined"/></xsl:when>
      <xsl:when test="$current-style='tt'"><xsl:call-template name="start-tt"/></xsl:when>
      <xsl:otherwise><xsl:call-template name="start-normal"/></xsl:otherwise>
    </xsl:choose>
  </xsl:if>
</xsl:template>

</xsl:stylesheet>
