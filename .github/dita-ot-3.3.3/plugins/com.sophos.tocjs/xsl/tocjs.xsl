<!-- 
This file is part of the DITA Open Toolkit project.

Copyright 2007 Shawn McKenzie

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:import href="topicref.xsl"/>
  <!--<xsl:import href="topichead.xsl"/>-->
  <xsl:import href="jstext.xsl"/>
  <xsl:import href="gethref.xsl"/>
 
  <xsl:param name="contentwin"/>
  <xsl:param name="htmlext"/>
  <xsl:output method="text" encoding="UTF-8"/>

  
  
  <xsl:template match="/">
    <xsl:message> At slash, contentwin is <xsl:value-of select="$contentwin"/></xsl:message>
    <xsl:if test="not($contentwin)">
    <xsl:message>
########################################################################      
###                                                                  ### 
### The 'content.frame' property is not set in your tocjs ant task!  ###
### Using 'contentwin' as a default.                                 ###
###                                                                  ###
########################################################################    </xsl:message>

    </xsl:if>
    
    <xsl:if test="$contentwin">
      <xsl:message>
########################################        
### Your 'content.frame' property is set to '<xsl:value-of select="$contentwin"/>' ###        
########################################
      </xsl:message>
      
    </xsl:if>
    
    <!-- need to output an html file that includes refs to necessary js and that builds
      a script element with js entries for the toc -->
    <xsl:text>
      var tree;
      
      function treeInit() {
      tree = new YAHOO.widget.TreeView("treeDiv1");
      var root = tree.getRoot();
    </xsl:text>    
    <xsl:if test="not($contentwin)">
      <xsl:apply-templates>
        <xsl:with-param name="contentwin" select="'contentwin'"/>
      </xsl:apply-templates>
    </xsl:if>
    <xsl:if test="$contentwin">
      <xsl:apply-templates>
        <xsl:with-param name="contentwin" select="$contentwin"/>
      </xsl:apply-templates>
    </xsl:if>
    
    <xsl:text>
      tree.draw(); 
      } 
      
      YAHOO.util.Event.addListener(window, "load", treeInit); 
    </xsl:text>          
    
  </xsl:template>

  
  
  <xsl:template match="*[contains(@class, ' map/map ')]">
    <xsl:param name="contentwin"/>
    <!--<xsl:message>########## in map/map, $contentwin param is <xsl:value-of select="$contentwin"/></xsl:message>-->
    <xsl:variable name="parent" select="'root'"/>
    <xsl:apply-templates>
      <xsl:with-param name="parent" select="$parent"/>
      <xsl:with-param name="contentwin" select="$contentwin"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/topicmeta ')]">
    <!-- do nothing for now -->
  </xsl:template>


  <xsl:template match="*[contains(@class, ' topic/title ')]">
    <!-- do nothing for now -->
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/navref ')]">
    <xsl:message> WARNING! navref not supported. </xsl:message>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/anchor ')]">
    <xsl:message> WARNING! anchor not supported. </xsl:message>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/reltable ')]">
    <!-- do nothing now -->
  </xsl:template>

</xsl:stylesheet>
