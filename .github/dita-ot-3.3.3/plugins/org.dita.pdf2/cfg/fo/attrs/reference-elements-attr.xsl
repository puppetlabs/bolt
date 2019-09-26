<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2012 Eero Helenius

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  xmlns:rx="http://www.renderx.com/XSL/Extensions"
  version="2.0">

  <xsl:attribute-set name="properties" use-attribute-sets="base-font">
    <xsl:attribute name="width">100%</xsl:attribute>
    <xsl:attribute name="space-before">8pt</xsl:attribute>
    <xsl:attribute name="space-after">10pt</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="properties__body">
  </xsl:attribute-set>

  <xsl:attribute-set name="property">
  </xsl:attribute-set>

  <xsl:attribute-set name="property.entry">
  </xsl:attribute-set>

  <xsl:attribute-set name="property.entry__keycol-content" use-attribute-sets="common.table.body.entry common.table.head.entry">
  </xsl:attribute-set>

  <xsl:attribute-set name="property.entry__content" use-attribute-sets="common.table.body.entry">
  </xsl:attribute-set>

  <xsl:attribute-set name="prophead">
  </xsl:attribute-set>

  <xsl:attribute-set name="prophead__row">
  </xsl:attribute-set>

  <xsl:attribute-set name="prophead.entry">
  </xsl:attribute-set>

  <xsl:attribute-set name="prophead.entry__keycol-content" use-attribute-sets="common.table.body.entry common.table.head.entry">
  </xsl:attribute-set>

  <xsl:attribute-set name="prophead.entry__content" use-attribute-sets="common.table.body.entry common.table.head.entry">
  </xsl:attribute-set>

  <xsl:attribute-set name="reference">
  </xsl:attribute-set>

  <xsl:attribute-set name="refbody" use-attribute-sets="body">
  </xsl:attribute-set>

  <xsl:attribute-set name="refsyn" use-attribute-sets="section">
  </xsl:attribute-set>

  <xsl:attribute-set name="refsyn__content" use-attribute-sets="section__content">
  </xsl:attribute-set>

</xsl:stylesheet>
