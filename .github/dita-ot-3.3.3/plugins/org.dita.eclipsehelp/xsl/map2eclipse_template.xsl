<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2010 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!-- Import the main ditamap to Eclipse TOC Contents conversion -->
<xsl:import href="plugin:org.dita.eclipsehelp:xsl/map2eclipse/map2eclipseImpl.xsl"/>

<dita:extension id="dita.xsl.eclipse.toc" behavior="org.dita.dost.platform.ImportXSLAction" xmlns:dita="http://dita-ot.sourceforge.net"/>

<xsl:output method="xml"
            encoding="UTF-8"
            indent="no"
/>

</xsl:stylesheet>
