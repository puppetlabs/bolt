<?xml version='1.0'?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2018 IBM

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    xmlns:rx="http://www.renderx.com/XSL/Extensions"
    xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
    exclude-result-prefixes="dita-ot xs"
    version="2.0">

    <xsl:template match="*|@alt" mode="graphicAlternateText">
        <xsl:attribute name="rx:alt-description"><xsl:apply-templates select="." mode="text-only"/></xsl:attribute>
    </xsl:template>

</xsl:stylesheet>
