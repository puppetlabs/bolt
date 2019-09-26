<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2010 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:import href="plugin:org.dita.base:xsl/common/dita-utilities.xsl"/>
<!-- Import the main ditamap to HTML Help Project file conversion -->
<xsl:import href="plugin:org.dita.htmlhelp:xsl/map2htmlhelp/map2hhpImpl.xsl"/>

<dita:extension id="dita.xsl.htmlhelp.map2hhp" behavior="org.dita.dost.platform.ImportXSLAction" xmlns:dita="http://dita-ot.sourceforge.net"/>

<xsl:output method="text"
            encoding="UTF-8"
/>

</xsl:stylesheet>
