<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="*[contains(@class,' ui-d/screen ')]" name="topic.ui-d.screen">
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:call-template name="spec-title-nospace"/>
    <codeblock class="screen">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setscale"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
    </codeblock>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>

  <xsl:template match="*[contains(@class,' ui-d/uicontrol ')]" name="topic.ui-d.uicontrol">
    <xsl:if test="ancestor::*[contains(@class,' ui-d/menucascade ')]">
      <xsl:variable name="uicontrolcount">
        <xsl:number count="*[contains(@class,' ui-d/uicontrol ')]"/>
      </xsl:variable>
      <xsl:if test="$uicontrolcount&gt;'1'">
        <xsl:text> > </xsl:text>
      </xsl:if>
    </xsl:if>
    <strong class="uicontrol">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
    </strong>
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

  <xsl:template match="*[contains(@class,' ui-d/menucascade ')]/text()"/>

  <xsl:template match="*[contains(@class,' ui-d/shortcut ')]" name="topic.ui-d.shortcut">
    <span class="shortcut">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
    </span>
  </xsl:template>

</xsl:stylesheet>
