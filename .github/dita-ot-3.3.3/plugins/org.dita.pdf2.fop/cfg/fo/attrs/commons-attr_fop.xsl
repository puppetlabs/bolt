<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2011 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                version="2.0">

  <xsl:attribute-set name="__toc__mini__table">
    <xsl:attribute name="table-layout">fixed</xsl:attribute>
    <xsl:attribute name="width">100%</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="note__table">
    <xsl:attribute name="table-layout">fixed</xsl:attribute>
    <xsl:attribute name="width">100%</xsl:attribute>
  </xsl:attribute-set>
  
  <xsl:attribute-set name="note__text__column">
    <xsl:attribute name="column-width">100% - 32pt</xsl:attribute>
  </xsl:attribute-set>
  
</xsl:stylesheet>
