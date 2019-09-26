<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:import href="ast2markdown.xsl"/>
  
  <xsl:import href="dita2markdownImpl.xsl"/>
  <!--xsl:import href="conceptdisplay.xsl"/>
  <xsl:import href="glossdisplay.xsl"/>
  <xsl:import href="taskdisplay.xsl"/>
  <xsl:import href="refdisplay.xsl"/-->
  <xsl:import href="task.xsl"/>
  <xsl:import href="ut-d.xsl"/>
  <xsl:import href="sw-d.xsl"/>
  <xsl:import href="pr-d.xsl"/>
  <xsl:import href="ui-d.xsl"/>
  <xsl:import href="hi-d.xsl"/>
  <!--xsl:import href="abbrev-d.xsl"/-->
  <xsl:import href="markup-d.xsl"/>
  <xsl:import href="xml-d.xsl"/>
  <dita:extension id="dita.xsl.markdown" behavior="org.dita.dost.platform.ImportXSLAction" xmlns:dita="http://dita-ot.sourceforge.net"/>
  <!--xsl:include href="markdownflag.xsl"/-->  
  
  <xsl:output method="text"
              encoding="utf-8"/>
  
  <xsl:template match="/">
    <xsl:variable name="ast" as="node()">
      <xsl:apply-templates/>
    </xsl:variable>
    <xsl:variable name="ast-flat" as="node()">
      <xsl:apply-templates select="$ast" mode="flatten"/>
    </xsl:variable>
    <xsl:variable name="ast-clean" as="node()">
      <xsl:apply-templates select="$ast-flat" mode="ast-clean"/>
    </xsl:variable>
    <xsl:apply-templates select="$ast-clean" mode="ast"/>
  </xsl:template>
  
</xsl:stylesheet>
