<?xml version="1.0"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2010 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<!-- This file is imported in to common code for use by any
     process that needs a text-only version of DITA content.
     Typically used when content needs to go into an attribute;
     preferred over using "value-of", which drops images, 
     includes index terms, etc. 

     To use, process any content with mode="dita-ot:text-only" -->
<xsl:stylesheet version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
  exclude-result-prefixes="dita-ot"
  >

  <xsl:import href="plugin:org.dita.base:xsl/common/topic2textonly.xsl"/>
  <xsl:import href="plugin:org.dita.base:xsl/common/map2textonly.xsl"/>
  <xsl:import href="plugin:org.dita.base:xsl/common/ui-d2textonly.xsl"/>
     
  
</xsl:stylesheet>
