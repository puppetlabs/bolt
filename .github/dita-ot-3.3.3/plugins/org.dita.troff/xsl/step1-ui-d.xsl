<?xml version="1.0"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2006 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="xml"/>

<xsl:template match="*[contains(@class, ' ui-d/screen ')]">
  <block>
    <xsl:attribute name="xml:space" select="'preserve'"/>
    <xsl:call-template name="commonatts"/>
    <xsl:apply-templates/>
  </block>
</xsl:template>

<xsl:template match="*[contains(@class, ' ui-d/shortcut ')]">
  <text style="underline"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
</xsl:template>

<xsl:template match="*[contains(@class, ' ui-d/uicontrol ')]">
  <xsl:if test="parent::*[contains(@class,' ui-d/menucascade ')] and preceding-sibling::*[contains(@class, ' ui-d/uicontrol ')]">
    <xsl:text> -> </xsl:text>
  </xsl:if>
  <text style="bold"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
</xsl:template>

<!--<xsl:template match="*[contains(@class, ' ui-d/uicontrol ')]" mode="text-only">
  <xsl:if test="parent::*[contains(@class,' ui-d/menucascade ')] and preceding-sibling::*[contains(@class, ' ui-d/uicontrol ')]">
    <xsl:text> -> </xsl:text>
  </xsl:if>
  <xsl:apply-templates select="*|text()" mode="text-only"/>
</xsl:template>-->

</xsl:stylesheet>
