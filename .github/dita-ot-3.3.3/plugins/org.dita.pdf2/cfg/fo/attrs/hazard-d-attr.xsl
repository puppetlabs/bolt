<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project. 
See the accompanying license.txt file for applicable licenses.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0">

  <!-- Source: https://www.nema.org/Standards/ComplimentaryDocuments/ANSI%20Z535_1-2017%20CONTENTS%20AND%20SCOPE.pdf -->
  <xsl:variable name="hazard.ansi.red" select="'#C8102E'"/>
  <xsl:variable name="hazard.ansi.orange" select="'#FF8200'"/>
  <xsl:variable name="hazard.ansi.yellow" select="'#FFD100'"/>
  <xsl:variable name="hazard.ansi.green" select="'#007B5F'"/>
  <xsl:variable name="hazard.ansi.blue" select="'#0072CE'"/>
  <xsl:variable name="hazard.ansi.purple" select="'#6D2077'"/>

  <!-- Source: https://en.wikipedia.org/wiki/ISO_3864 -->
  <xsl:variable name="hazard.iso.red" select="'#9B2423'"/>
  <xsl:variable name="hazard.iso.yellow" select="'#F9A800'"/>
  <xsl:variable name="hazard.iso.green" select="'#237F52'"/>
  <xsl:variable name="hazard.iso.blue" select="'#005387'"/>
  
  <xsl:attribute-set name="hazardstatement">
    <xsl:attribute name="width">100%</xsl:attribute>
    <xsl:attribute name="space-before">8pt</xsl:attribute>
    <xsl:attribute name="space-after">10pt</xsl:attribute>
    <xsl:attribute name="border-style">solid</xsl:attribute>
    <xsl:attribute name="border-color">black</xsl:attribute>
    <xsl:attribute name="border-width">5pt</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="hazardstatement.cell">
    <xsl:attribute name="start-indent">0pt</xsl:attribute>
    <xsl:attribute name="border-style">solid</xsl:attribute>
    <xsl:attribute name="border-color">black</xsl:attribute>
    <xsl:attribute name="border-width">2pt</xsl:attribute>
    <xsl:attribute name="padding">3pt</xsl:attribute>
    <xsl:attribute name="keep-together">always</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="hazardstatement.title" use-attribute-sets="hazardstatement.cell common.title">
    <xsl:attribute name="number-columns-spanned">2</xsl:attribute>
    <xsl:attribute name="text-transform">uppercase</xsl:attribute>
    <xsl:attribute name="font-weight">bold</xsl:attribute>
    <xsl:attribute name="font-size">1.5em</xsl:attribute>
    <xsl:attribute name="text-align">center</xsl:attribute>
  </xsl:attribute-set>
  
  <xsl:attribute-set name="hazardstatement.title.danger">
    <xsl:attribute name="color">white</xsl:attribute>
    <xsl:attribute name="background-color" select="$hazard.ansi.red"/>
    <xsl:attribute name="font-style">normal</xsl:attribute>
  </xsl:attribute-set>
  <xsl:attribute-set name="hazardstatement.title.warning">
    <xsl:attribute name="background-color" select="$hazard.ansi.orange"/>
    <xsl:attribute name="font-style">normal</xsl:attribute>
  </xsl:attribute-set>
  <xsl:attribute-set name="hazardstatement.title.caution">
    <xsl:attribute name="background-color" select="$hazard.ansi.yellow"/>
    <xsl:attribute name="font-style">normal</xsl:attribute>
  </xsl:attribute-set>
  <xsl:attribute-set name="hazardstatement.title.notice">
    <xsl:attribute name="color">white</xsl:attribute>
    <xsl:attribute name="font-style">italic</xsl:attribute>
    <xsl:attribute name="background-color" select="$hazard.ansi.blue"/>
  </xsl:attribute-set>

  <xsl:attribute-set name="hazardstatement.image" use-attribute-sets="hazardstatement.cell">
    <xsl:attribute name="text-align">center</xsl:attribute>
  </xsl:attribute-set>
  
  <xsl:attribute-set name="hazardstatement.image.column">
    <xsl:attribute name="column-width">6em</xsl:attribute>
  </xsl:attribute-set>

  <xsl:attribute-set name="hazardstatement.content" use-attribute-sets="hazardstatement.cell">
    
  </xsl:attribute-set>

  <xsl:attribute-set name="hazardstatement.content.column">
    
  </xsl:attribute-set>
  
  <xsl:attribute-set name="messagepanel">
    
  </xsl:attribute-set>
  
  <xsl:attribute-set name="consequence">
    
  </xsl:attribute-set>
  
  <xsl:attribute-set name="howtoavoid">
    
  </xsl:attribute-set>
  
  <xsl:attribute-set name="typeofhazard">
    
  </xsl:attribute-set>
  
  <xsl:attribute-set name="hazardsymbol" use-attribute-sets="image">
    <xsl:attribute name="content-width">4em</xsl:attribute>
    <xsl:attribute name="width">4em</xsl:attribute>
  </xsl:attribute-set>
  
</xsl:stylesheet>