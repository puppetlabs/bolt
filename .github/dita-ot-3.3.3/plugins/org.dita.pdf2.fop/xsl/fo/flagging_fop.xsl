<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2013 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:fo="http://www.w3.org/1999/XSL/Format"
                xmlns:suitesol="http://suite-sol.com/namespaces/mapcounts"
                exclude-result-prefixes="suitesol"
                version="2.0">

  <!-- FOP crashes if changebar elements appear in fo:block or fo:inline,
       which is where all are currently generated -->
  <xsl:template match="suitesol:changebar-start"/>
  <xsl:template match="suitesol:changebar-end"/>   
     
  <xsl:template match="*[contains(@class,' ditaot-d/ditaval-startprop ')]/revprop" mode="changebar"/>
  <xsl:template match="*[contains(@class,' ditaot-d/ditaval-endprop ')]/revprop" mode="changebar"/>

</xsl:stylesheet>
