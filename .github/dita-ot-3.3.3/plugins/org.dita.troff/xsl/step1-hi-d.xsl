<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2006 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                >

<xsl:template match="*[contains(@class,' hi-d/b ')]">
    <text style="bold"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
</xsl:template>
<xsl:template match="*[contains(@class,' hi-d/i ')]">
    <text style="italics"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
</xsl:template>

<!-- Note that troff only seems to allow 3 different styles: normal, bold, italics. -->
<xsl:template match="*[contains(@class,' hi-d/u ')]">
    <text style="underlined"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
</xsl:template>
<xsl:template match="*[contains(@class,' hi-d/tt ')]">
    <text style="tt"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
</xsl:template>
<xsl:template match="*[contains(@class,' hi-d/sup ')]">
    <text style="sup"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
</xsl:template>
<xsl:template match="*[contains(@class,' hi-d/sub ')]">
    <text style="sub"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
</xsl:template>

</xsl:stylesheet>
