<?xml version="1.0"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2006 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="xml"/>

<xsl:template match="*[contains(@class,' sw-d/msgph ')]">
  <text style="tt"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
</xsl:template>

<xsl:template match="*[contains(@class,' sw-d/systemoutput ')]">
  <text style="tt"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
</xsl:template>

<xsl:template match="*[contains(@class,' sw-d/userinput ')]">
  <text style="tt"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
</xsl:template>

<xsl:template match="*[contains(@class,' sw-d/varname ')]">
  <text style="italics"><xsl:call-template name="commonatts"/><xsl:apply-templates/></text>
</xsl:template>

</xsl:stylesheet>
