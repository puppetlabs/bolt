<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="*[contains(@class,' ui-d/screen ')]" name="topic.ui-d.screen">
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:call-template name="spec-title-nospace"/>
    <pre class="screen">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setscale"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
    </pre>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>

  <xsl:template match="*[contains(@class,' ui-d/uicontrol ')]" name="topic.ui-d.uicontrol">
  <!-- insert an arrow with leading/trailing spaces before all but the first uicontrol in a menucascade -->
  <xsl:if test="ancestor::*[contains(@class,' ui-d/menucascade ')]">
   <xsl:variable name="uicontrolcount"><xsl:number count="*[contains(@class,' ui-d/uicontrol ')]"/></xsl:variable>
    <xsl:if test="$uicontrolcount&gt;'1'">
      <xsl:variable name="a11y.text" as="text()?">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'a11y.and-then'"/>
        </xsl:call-template>
      </xsl:variable>
      <abbr>
        <xsl:if test="exists($a11y.text)">
          <xsl:attribute name="title" select="$a11y.text"/>          
        </xsl:if>
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'#menucascade-separator'"/>
        </xsl:call-template>
      </abbr>
    </xsl:if>
  </xsl:if>
   <span class="uicontrol">
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' ui-d/wintitle ')]" name="topic.ui-d.wintitle">
   <span class="wintitle">
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' ui-d/menucascade ')]" name="topic.ui-d.menucascade">
   <span class="menucascade">
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>
  <!-- Ignore text inside menucascade -->
  <xsl:template match="*[contains(@class,' ui-d/menucascade ')]/text()"/>
  
  <xsl:template match="*[contains(@class,' ui-d/shortcut ')]" name="topic.ui-d.shortcut">
   <span class="shortcut">
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
   </span>
  </xsl:template>

</xsl:stylesheet>
