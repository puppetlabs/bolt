<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:template match="*[contains(@class,' hi-d/b ')]" name="topic.hi-d.b">
   <strong>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
    </strong>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' hi-d/i ')]" name="topic.hi-d.i">
   <em>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
    </em>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' hi-d/u ')]" name="topic.hi-d.u">
   <u>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
    </u>
  </xsl:template>
  
    <xsl:template match="*[contains(@class,' hi-d/tt ')]" name="topic.hi-d.tt">
      <span style="font-family: monospace">
        <xsl:call-template name="commonattributes"/>
        <xsl:if test="*[contains(@class,' ditaot-d/ditaval-startprop ')]/@outputclass">
          <!-- Combine TT style with style from ditaval, if present -->
          <xsl:attribute name="style">
            <xsl:text>font-family: monospace; </xsl:text>
            <xsl:value-of select="*[contains(@class,' ditaot-d/ditaval-startprop ')]/@outputclass"/>
          </xsl:attribute>
        </xsl:if>
        <xsl:call-template name="setidaname"/>
        <xsl:apply-templates/>
      </span>
    </xsl:template>
  
  <xsl:template match="*[contains(@class,' hi-d/sup ')]" name="topic.hi-d.sup">
   <sup>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </sup>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' hi-d/sub ')]" name="topic.hi-d.sub">
   <sub>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
    </sub>
  </xsl:template>

  <xsl:template match="*[contains(@class,' hi-d/line-through ')]" name="topic.hi-d.line-through">
    <span style="text-decoration:line-through">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>

  <xsl:template match="*[contains(@class,' hi-d/overline ')]" name="topic.hi-d.overline">
    <span style="text-decoration:overline">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>  

</xsl:stylesheet>
