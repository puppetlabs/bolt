<?xml version="1.0" encoding="UTF-8"?><!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
--><xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">

<!-- idit2htm.xsl   main stylesheet
 | Convert DITA topic to HTML; "single topic to single web page"-level view
 |
-->

<!-- stylesheet imports -->
<!-- the main dita to xhtml converter -->
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/dita2htmlImpl.xsl"/>

<!-- the dita to xhtml converter for concept documents -->
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/conceptdisplay.xsl"/>

<!-- the dita to xhtml converter for glossentry documents -->
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/glossdisplay.xsl"/>

<!-- the dita to xhtml converter for task documents -->
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/taskdisplay.xsl"/>

<!-- the dita to xhtml converter for reference documents -->
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/refdisplay.xsl"/>

<!-- user technologies domain -->
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/ut-d.xsl"/>
<!-- software domain -->
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/sw-d.xsl"/>
<!-- programming domain -->
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/pr-d.xsl"/>
<!-- ui domain -->
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/ui-d.xsl"/>
<!-- highlighting domain -->
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/hi-d.xsl"/>
<!-- abbreviated-form domain -->
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/abbrev-d.xsl"/>
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/markup-d.xsl"/>
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/xml-d.xsl"/>
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/svg-d.xsl"/>
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/hazard-d.xsl"/>
<!-- Integrate support for flagging with dita-ot pseudo-domain -->
<xsl:import href="plugin:org.dita.xhtml:xsl/xslhtml/htmlflag.xsl"/>  



<!-- the dita to xhtml converter for element reference documents - not used now -->
<!--<xsl:import href="elementrefdisp.xsl"/>-->

<!-- root rule -->
<xsl:template xmlns:dita="http://dita-ot.sourceforge.net" match="/">
  <xsl:apply-templates/>
</xsl:template>

</xsl:stylesheet>