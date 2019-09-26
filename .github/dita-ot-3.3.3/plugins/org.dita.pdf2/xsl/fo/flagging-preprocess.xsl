<?xml version="1.0" encoding="UTF-8"?><!-- Deprecated since 2.2 --><!--
This file is part of the DITA Open Toolkit project.

Copyright 2011 Reuven Weiser

See the accompanying LICENSE file for applicable license.
--><xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:opentopic-func="http://www.idiominc.com/opentopic/exsl/function" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:suitesol="http://suite-sol.com/namespaces/mapcounts" exclude-result-prefixes="xsl opentopic-func xs" version="2.0">

   <xsl:import href="plugin:org.dita.pdf2:xsl/fo/flag-rules.xsl"/>
   <xsl:import href="plugin:org.dita.base:xsl/common/dita-utilities.xsl"/>
   <xsl:import href="plugin:org.dita.base:xsl/common/output-message.xsl"/>
  
   

   <!--preserve the doctype-->
   <xsl:output xmlns:dita="http://dita-ot.sourceforge.net" method="xml" encoding="UTF-8" indent="no"/>


   <xsl:param name="filterFile" select="''"/>

   <!-- The document tree of filterfile returned by document($FILTERFILE,/)-->

   <!-- Define the error message prefix identifier -->
   <!-- Deprecated since 2.3 -->
   <xsl:variable name="msgprefix">DOTX</xsl:variable>

   <xsl:variable name="FILTERFILEURL">
      <xsl:choose>
         <xsl:when test="not($filterFile)"/>
         <!-- If no filterFile leave empty -->
         <xsl:when test="starts-with($filterFile,'file:')">
            <xsl:value-of select="$filterFile"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:choose>
               <xsl:when test="starts-with($filterFile,'/')">
                  <xsl:text>file://</xsl:text>
                  <xsl:value-of select="$filterFile"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>file:/</xsl:text>
                  <xsl:value-of select="$filterFile"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:variable>

   <xsl:variable name="flagsParams" select="document($FILTERFILEURL,/)"/>
   
   <xsl:template match="*" mode="flagging">
      <xsl:param name="pi-name"/>
      <xsl:param name="id"/>
      <xsl:param name="flagrules"/>

      <xsl:if test="$flagrules">
         <xsl:variable name="conflictexist">
            <xsl:apply-templates select="." mode="conflict-check">
               <xsl:with-param name="flagrules" select="$flagrules"/>
            </xsl:apply-templates>
         </xsl:variable>

         <xsl:variable name="style">
            <xsl:call-template name="gen-style">
               <xsl:with-param name="conflictexist" select="$conflictexist"/>
               <xsl:with-param name="flagrules" select="$flagrules"/>
            </xsl:call-template>
         </xsl:variable>
        

         <xsl:if test="string-length($style) &gt; 0">

            <xsl:element name="suitesol:{$pi-name}">
               <xsl:attribute name="id">
                  <xsl:value-of select="$id"/>
               </xsl:attribute>
               <xsl:attribute name="style">
                  <xsl:value-of select="$style"/>
               </xsl:attribute>
            </xsl:element>
         </xsl:if>
       </xsl:if>
           
   </xsl:template>

   <xsl:template match="*" mode="changebar">
      <xsl:param name="pi-name"/>
      <xsl:param name="id"/>
      <xsl:param name="flagrules"/>

      <xsl:if test="$flagrules">
         <xsl:for-each select="$flagrules/*[@changebar]">
            
            <xsl:element name="{concat('suitesol:changebar-',$pi-name)}">
               <xsl:attribute name="id">
                  <xsl:value-of select="concat($id,'_',count(preceding::*))"/>
               </xsl:attribute>
               <xsl:if test="$pi-name='start'">
                  <xsl:attribute name="changebar">
                     <xsl:value-of select="@changebar"/>
                  </xsl:attribute>
               </xsl:if>
            </xsl:element>
         </xsl:for-each>

      </xsl:if>

   </xsl:template>

   <xsl:template match="*" mode="copy-contents">

      <xsl:param name="id"/>
      <xsl:param name="flagrules"/>

      <xsl:call-template name="start-flagit">
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:call-template>

      <xsl:copy>
         <xsl:apply-templates select="@*"/>

         <xsl:apply-templates/>

      </xsl:copy>

      <xsl:call-template name="end-flagit">
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:call-template>

   </xsl:template>
   
   <!-- Don't flag topics, just like in the HTML output -->
   <xsl:template match="*[contains(@class, ' topic/topic ')]" priority="50">
      <xsl:copy>
         <xsl:apply-templates select="@*"/>
         <xsl:apply-templates/>
      </xsl:copy>
   </xsl:template>
              
   <!-- For these elements, the flagging style can be applied directly to the fo element 
        already being created by the default DITA-OT processing -->
   <xsl:template match="*[contains(@class, ' topic/image ') or                contains(@class, ' svg-d/svgref ') or                contains(@class,' topic/table ') or                contains(@class, ' topic/ol ') or                 contains(@class, ' topic/ul ') or contains(@class, ' topic/sl ')]" priority="50">

      <xsl:variable name="id" select="generate-id(.)" as="xs:string"/>

      <xsl:variable name="flagrules">
         <xsl:apply-templates select="." mode="getrules">
         </xsl:apply-templates>
      </xsl:variable>
      
      <xsl:apply-templates select="." mode="changebar">
         <xsl:with-param name="pi-name">start</xsl:with-param>
         <xsl:with-param name="id" select="$id"/>
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:apply-templates>
      
      <xsl:call-template name="start-flagit">
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:call-template>
      
      <xsl:copy>
         <xsl:apply-templates select="@*"/>

         <xsl:apply-templates select="." mode="flagging">
            <xsl:with-param name="pi-name">flagging-inside</xsl:with-param>
            <xsl:with-param name="id" select="$id"/>
            <xsl:with-param name="flagrules" select="$flagrules"/>
         </xsl:apply-templates>


         <xsl:apply-templates/>

      </xsl:copy>
      
      <xsl:call-template name="end-flagit">
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:call-template>

      <xsl:apply-templates select="." mode="changebar">
         <xsl:with-param name="pi-name">end</xsl:with-param>
         <xsl:with-param name="id" select="$id"/>
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:apply-templates>
      
   </xsl:template>

   <!-- For these elements, the flagging style must be applied to a new fo:block around the element,
        which for now is place-held by the suitesol:flagging-outside element -->
   <xsl:template match="*[contains(@class, ' topic/simpletable ') or contains(@class, ' topic/dl ') or contains(@class, ' topic/note ') or contains(@class, ' pr-d/codeblock ') or contains(@class, ' ui-d/screen ')]" priority="40">

      <xsl:variable name="id" select="generate-id(.)" as="xs:string"/>

      <xsl:variable name="flagrules">
         <xsl:apply-templates select="." mode="getrules">
         </xsl:apply-templates>
      </xsl:variable>

      <xsl:apply-templates select="." mode="changebar">
         <xsl:with-param name="pi-name">start</xsl:with-param>
         <xsl:with-param name="id" select="$id"/>
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:apply-templates>

      <xsl:variable name="style">
         <xsl:if test="$flagrules">
            <xsl:variable name="conflictexist">
               <xsl:apply-templates select="." mode="conflict-check">
                  <xsl:with-param name="flagrules" select="$flagrules"/>
               </xsl:apply-templates>
            </xsl:variable>
            <xsl:call-template name="gen-style">
               <xsl:with-param name="conflictexist" select="$conflictexist"/>
               <xsl:with-param name="flagrules" select="$flagrules"/>
            </xsl:call-template>
         </xsl:if>
      </xsl:variable>

      <xsl:choose>
         <xsl:when test="string-length(normalize-space($style)) &gt; 0">
            <suitesol:flagging-outside style="{$style}">
               <xsl:apply-templates select="." mode="copy-contents">
                  <xsl:with-param name="id" select="$id"/>
                  <xsl:with-param name="flagrules" select="$flagrules"/>

               </xsl:apply-templates>
            </suitesol:flagging-outside>
         </xsl:when>
         <!-- If there's no style, don't bother creating the surrounding block -->
         <xsl:otherwise>
            <xsl:apply-templates select="." mode="copy-contents">
               <xsl:with-param name="id" select="$id"/>
               <xsl:with-param name="flagrules" select="$flagrules"/>

            </xsl:apply-templates>
         </xsl:otherwise>
      </xsl:choose>

      <xsl:apply-templates select="." mode="changebar">
         <xsl:with-param name="pi-name">end</xsl:with-param>
         <xsl:with-param name="id">
            <xsl:value-of select="$id"/>
         </xsl:with-param>
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:apply-templates>

   </xsl:template>

   <!-- For these elements, the flagging style must be applied to a new fo:inline around the element,
      which for now is place-held by the suitesol:flagging-outside-inline element -->
   <xsl:template match="*[contains(@class, ' topic/xref ') or contains(@class, ' topic/link ')]" priority="40">

      <xsl:variable name="id" select="generate-id(.)" as="xs:string"/>

      <xsl:variable name="flagrules">
         <xsl:apply-templates select="." mode="getrules">
         </xsl:apply-templates>
      </xsl:variable>

      <xsl:apply-templates select="." mode="changebar">
         <xsl:with-param name="pi-name">start</xsl:with-param>
         <xsl:with-param name="id" select="$id"/>
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:apply-templates>

      <xsl:variable name="style">
         <xsl:if test="$flagrules">
            <xsl:variable name="conflictexist">
               <xsl:apply-templates select="." mode="conflict-check">
                  <xsl:with-param name="flagrules" select="$flagrules"/>
               </xsl:apply-templates>
            </xsl:variable>
            <xsl:call-template name="gen-style">
               <xsl:with-param name="conflictexist" select="$conflictexist"/>
               <xsl:with-param name="flagrules" select="$flagrules"/>
            </xsl:call-template>
         </xsl:if>
      </xsl:variable>

      <xsl:choose>
         <xsl:when test="string-length(normalize-space($style)) &gt; 0">
            <suitesol:flagging-outside-inline style="{$style}">
               <xsl:apply-templates select="." mode="copy-contents">
                  <xsl:with-param name="id" select="$id"/>
                  <xsl:with-param name="flagrules" select="$flagrules"/>

               </xsl:apply-templates>
            </suitesol:flagging-outside-inline>
         </xsl:when>

         <xsl:otherwise>
            <xsl:apply-templates select="." mode="copy-contents">
               <xsl:with-param name="id" select="$id"/>
               <xsl:with-param name="flagrules" select="$flagrules"/>

            </xsl:apply-templates>
         </xsl:otherwise>
      </xsl:choose>

      <xsl:apply-templates select="." mode="changebar">
         <xsl:with-param name="pi-name">end</xsl:with-param>
         <xsl:with-param name="id">
            <xsl:value-of select="$id"/>
         </xsl:with-param>
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:apply-templates>
   </xsl:template>


   <!-- For these elements, the flagging style can be applied directly to the fo element 
      already being created by the default DITA-OT processing, but now the startflag and endflag images 
      are placed inside the element rather than before and after it -->
   <xsl:template match="*[contains(@class,' topic/entry ') or contains(@class, ' topic/stentry ') or                contains(@class, ' topic/dd ') or contains(@class, ' topic/dt ') or                 contains(@class, ' topic/ddhd ') or contains(@class, ' topic/dthd ')]" priority="30">

      <xsl:variable name="id" select="generate-id(.)" as="xs:string"/>
      
      <xsl:variable name="flagrules">
         <xsl:apply-templates select=". | parent::*" mode="getrules">
         </xsl:apply-templates>
      </xsl:variable>

      <xsl:apply-templates select="." mode="changebar">
         <xsl:with-param name="pi-name">start</xsl:with-param>
         <xsl:with-param name="id" select="$id"/>
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:apply-templates>
      
      <xsl:copy>

         <xsl:apply-templates select="@*"/>

         <!-- copy attributes from parents -->       
         <xsl:apply-templates select="." mode="flagging">
            <xsl:with-param name="pi-name">flagging-inside</xsl:with-param>
            <xsl:with-param name="id" select="$id"/>
            <xsl:with-param name="flagrules" select="$flagrules"/>
         </xsl:apply-templates>
     
         <xsl:call-template name="start-flagit">
            <xsl:with-param name="flagrules" select="$flagrules"/>
         </xsl:call-template>

         <xsl:apply-templates/>

         <xsl:call-template name="end-flagit">
            <xsl:with-param name="flagrules" select="$flagrules"/>
         </xsl:call-template>
    
      </xsl:copy>

      <xsl:apply-templates select="." mode="changebar">
         <xsl:with-param name="pi-name">end</xsl:with-param>
         <xsl:with-param name="id" select="$id"/>
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:apply-templates>
      
   </xsl:template>

   <!-- For these elements, the flagging style can be applied directly to the fo element 
      already being created by the default DITA-OT processing, 
      but startflag and endflag images are not supported (where would they go?) -->
   <xsl:template match="*[contains(@class,' topic/tgroup ') or contains(@class, ' topic/thead ') or                contains(@class,' topic/tfoot ') or contains(@class,' topic/tbody ') or contains(@class,' topic/row ') or contains(@class, ' topic/strow ') or                contains(@class, ' topic/dlentry ') or contains(@class, ' topic/dlhead ') or                 contains(@class, ' topic/sthead ')]" priority="20">

      <xsl:variable name="id" select="generate-id(.)" as="xs:string"/>
      <xsl:variable name="flagrules">
         <xsl:apply-templates select="." mode="getrules">
         </xsl:apply-templates>
      </xsl:variable>

      <xsl:apply-templates select="." mode="changebar">
         <xsl:with-param name="pi-name">start</xsl:with-param>
         <xsl:with-param name="id" select="$id"/>
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:apply-templates>
      
      <xsl:copy>
         <xsl:apply-templates select="@*"/>

         <xsl:apply-templates select="." mode="flagging">
            <xsl:with-param name="pi-name">flagging-inside</xsl:with-param>
            <xsl:with-param name="id" select="$id"/>
            <xsl:with-param name="flagrules" select="$flagrules"/>
         </xsl:apply-templates>

         <xsl:apply-templates/>        
      </xsl:copy>

      <xsl:apply-templates select="." mode="changebar">
         <xsl:with-param name="pi-name">end</xsl:with-param>
         <xsl:with-param name="id" select="$id"/>
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:apply-templates>
      
   </xsl:template>
                
   <!-- For all other elements, we try to apply the flagging style directly to the fo element 
      already being created by the default DITA-OT processing, and place the startflag and endflag images 
      inside the element -->
   <xsl:template match="*" priority="-1">

      <xsl:variable name="id" select="generate-id(.)" as="xs:string"/>

      <xsl:variable name="flagrules">
         <xsl:apply-templates select="." mode="getrules">
         </xsl:apply-templates>
      </xsl:variable>

      <xsl:apply-templates select="." mode="changebar">
         <xsl:with-param name="pi-name">start</xsl:with-param>
         <xsl:with-param name="id" select="$id"/>
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:apply-templates>
      
      <xsl:copy>
         <xsl:apply-templates select="@*"/>

         <xsl:apply-templates select="." mode="flagging">
            <xsl:with-param name="pi-name">flagging-inside</xsl:with-param>
            <xsl:with-param name="id" select="$id"/>
            <xsl:with-param name="flagrules" select="$flagrules"/>
         </xsl:apply-templates>

         <xsl:call-template name="start-flagit">
            <xsl:with-param name="flagrules" select="$flagrules"/>
         </xsl:call-template>

         <xsl:apply-templates/>

         <xsl:call-template name="end-flagit">
            <xsl:with-param name="flagrules" select="$flagrules"/>
         </xsl:call-template>
        
      </xsl:copy>
      
      <xsl:apply-templates select="." mode="changebar">
         <xsl:with-param name="pi-name">end</xsl:with-param>
         <xsl:with-param name="id" select="$id"/>
         <xsl:with-param name="flagrules" select="$flagrules"/>
      </xsl:apply-templates>
      
   </xsl:template>

   <xsl:template match="@*" priority="-1">
      <xsl:copy-of select="."/>
   </xsl:template>

   <!-- copy over all comments so that <a> won't be empty -->
   <xsl:template match="comment() | processing-instruction() | text()">
      <xsl:copy-of select="."/>
   </xsl:template>  
   
   <xsl:template name="gen-style">
      <xsl:param name="conflictexist" select="'false'"/>
      <xsl:param name="flagrules"/>

      <xsl:variable name="colorprop">
         <xsl:choose>
            <xsl:when test="contains(@class, ' topic/image ') or contains(@class, ' svg-d/svgref ')">
               <xsl:text>border-style:solid;border-width:1pt;border-color:</xsl:text>
            </xsl:when>
            <xsl:otherwise>color:</xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:variable name="back-colorprop">
         <xsl:choose>
            <xsl:when test="contains(@class, ' topic/image ') or contains(@class, ' svg-d/svgref ')">
               <xsl:text>border-style:solid;border-width:3pt;border-color:</xsl:text>
            </xsl:when>
            <xsl:otherwise>background-color:</xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      
      <xsl:choose>
         <xsl:when test="$conflictexist='true' and $flagsParams/val/style-conflict[@foreground-conflict-color or @background-conflict-color]">
            <xsl:call-template name="output-message">
               <xsl:with-param name="id" select="'DOTX054W'"/>
            </xsl:call-template>

            <xsl:if test="$flagsParams/val/style-conflict[@foreground-conflict-color]">
               <xsl:value-of select="$colorprop"/>
               <xsl:value-of select="$flagsParams/val/style-conflict/@foreground-conflict-color"/>
               <xsl:text>;</xsl:text>
            </xsl:if>
            <xsl:if test="$flagsParams/val/style-conflict[@background-conflict-color]">
               <xsl:value-of select="$back-colorprop"/>
               <xsl:value-of select="$flagsParams/val/style-conflict/@background-conflict-color"/>
               <xsl:text>;</xsl:text>
            </xsl:if>

         </xsl:when>
         <xsl:when test="$conflictexist='false' and $flagrules/*[@color or @backcolor]">

            <xsl:if test="$flagrules/*[@color]">
               <xsl:value-of select="$colorprop"/>
               <xsl:value-of select="$flagrules/*[@color]/@color"/>
               <xsl:text>;</xsl:text>
            </xsl:if>
            <xsl:if test="$flagrules/*[@backcolor]">
               <xsl:value-of select="$back-colorprop"/>
               <xsl:value-of select="$flagrules/*[@backcolor]/@backcolor"/>
               <xsl:text>;</xsl:text>
            </xsl:if>

         </xsl:when>
      </xsl:choose>
      
      <xsl:for-each select="$flagrules/*[@style]">
            <xsl:choose>
               <xsl:when test="./@style='bold'">
                  <xsl:text>font-weight:</xsl:text>
               </xsl:when>
               <xsl:when test="./@style='italics' or ./@style='italic'">
                  <xsl:text>font-style:</xsl:text>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:text>text-decoration:</xsl:text>
               </xsl:otherwise>
            </xsl:choose>
            <xsl:choose>
               <xsl:when test="./@style='double-underline'">
                  <xsl:text>underline</xsl:text>
               </xsl:when>
               <xsl:when test="./@style='italics'">
                  <xsl:text>italic</xsl:text>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="./@style"/>
               </xsl:otherwise>
            </xsl:choose>
             <xsl:text>;</xsl:text>
      </xsl:for-each>
   </xsl:template>

   <xsl:template name="start-flagit">
      <xsl:param name="flagrules"/>
      <xsl:apply-templates select="$flagrules/*[1]" mode="start-flagit"/>
   </xsl:template>

   <xsl:template match="prop|revprop" mode="start-flagit">
      <xsl:choose>
         <!-- Ensure there's an image to get, otherwise don't insert anything -->
         <xsl:when test="startflag/@imageref">
            <xsl:variable name="imgsrc" select="startflag/@imageref"/>
            <image class="- topic/image " placement="inline">
               <xsl:attribute name="href">                  
                  <xsl:value-of select="$imgsrc"/>
               </xsl:attribute>
               <xsl:if test="startflag/alt-text">
                  <xsl:attribute name="alt">
                     <xsl:value-of select="startflag/alt-text"/>
                  </xsl:attribute>
               </xsl:if>
            </image>
         </xsl:when>
         <xsl:when test="startflag/alt-text">
            <xsl:value-of select="startflag/alt-text"/>
         </xsl:when>
         <xsl:when test="@img">
            <!-- output the flag -->
            <image class="- topic/image " placement="inline">
               <xsl:attribute name="href">                  
                  <xsl:value-of select="@img"/>
               </xsl:attribute>               
            </image>
         </xsl:when>
         <xsl:otherwise/>
         <!-- that flag not active -->
      </xsl:choose>
      <xsl:apply-templates select="following-sibling::*[1]" mode="start-flagit"/>
   </xsl:template>

   <xsl:template name="end-flagit">
      <xsl:param name="flagrules">
         <!--xsl:call-template name="getrules"/-->
      </xsl:param>
      <xsl:apply-templates select="$flagrules/*[last()]" mode="end-flagit"/>
   </xsl:template>

   <xsl:template match="prop|revprop" mode="end-flagit">
      <xsl:choose>
         <!-- Ensure there's an image to get, otherwise don't insert anything -->
         <xsl:when test="endflag/@imageref">
            <xsl:variable name="imgsrc" select="endflag/@imageref"/>
            <image class="- topic/image " placement="inline">
               <xsl:attribute name="href">               
                  <xsl:value-of select="$imgsrc"/>
               </xsl:attribute>
               <xsl:if test="endflag/alt-text">
                  <xsl:attribute name="alt">
                     <xsl:value-of select="endflag/alt-text"/>
                  </xsl:attribute>
               </xsl:if>
            </image>
         </xsl:when>
         <xsl:when test="endflag/alt-text">
            <xsl:value-of select="endflag/alt-text"/>
         </xsl:when>
         <!-- not necessary to add logic for @img. original ditaval does not support end flag. -->
         <xsl:otherwise/>
         <!-- that flag not active -->
      </xsl:choose>
      <xsl:apply-templates select="preceding-sibling::*[1]" mode="end-flagit"/>
   </xsl:template>


</xsl:stylesheet>