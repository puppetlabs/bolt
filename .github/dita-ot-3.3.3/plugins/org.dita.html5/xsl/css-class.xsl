<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2016 Eero Helenius

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                version="2.0"
                exclude-result-prefixes="xs dita-ot">

  <xsl:function name="dita-ot:css-class" as="xs:string">
    <xsl:param name="block-name" as="xs:string?"/>
    <xsl:param name="attr" as="attribute()"/>

    <xsl:sequence select="
      string-join(($block-name, concat(node-name($attr), '-', $attr)), '--')
    "/>
  </xsl:function>

  <xsl:function name="dita-ot:css-class" as="xs:string">
    <xsl:param name="attr" as="attribute()"/>

    <xsl:sequence select="
      dita-ot:css-class(xs:string(node-name($attr/parent::*)), $attr)
    "/>
  </xsl:function>

  <!-- Don't generate CSS classes for any element or attribute by default. -->
  <xsl:template match="* | @*" mode="css-class"/>

  <!-- Display attributes group -->
  <xsl:template match="@frame | @expanse | @scale" mode="css-class">
    <xsl:sequence select="dita-ot:css-class((), .)"/>
  </xsl:template>

  <xsl:template match="*" mode="css-class" priority="100">
    <xsl:param name="default-output-class"/>

    <xsl:variable name="outputclass" as="attribute(class)?">
      <xsl:apply-templates select="." mode="set-output-class">
        <xsl:with-param name="default" select="$default-output-class"/>
      </xsl:apply-templates>
    </xsl:variable>

    <xsl:variable name="class" as="xs:string*">
      <xsl:if test="$outputclass">
        <xsl:sequence select="data($outputclass)"/>
      </xsl:if>
      <xsl:next-match/>
    </xsl:variable>

    <xsl:if test="exists($class)">
      <xsl:attribute name="class" select="string-join($class, ' ')"/>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
