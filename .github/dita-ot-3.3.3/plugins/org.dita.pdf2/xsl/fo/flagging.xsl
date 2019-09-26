<?xml version='1.0' encoding="UTF-8"?>

<!--
Copyright © 2009 by Suite Solutions, Ltd. All rights reserved.
All other trademarks are the property of their respective owners.

Suite Solutions, Ltd. IS DELIVERING THE SOFTWARE "AS IS," WITH
ABSOLUTELY NO WARRANTIES WHATSOEVER, WHETHER EXPRESS OR IMPLIED,  AND IDIOM
TECHNOLOGIES, INC. DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE AND WARRANTY OF NON-INFRINGEMENT. IDIOM TECHNOLOGIES, INC. SHALL NOT
BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, COVER, PUNITIVE, EXEMPLARY,
RELIANCE, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF
ANTICIPATED PROFIT), ARISING FROM ANY CAUSE UNDER OR RELATED TO  OR ARISING
OUT OF THE USE OF OR INABILITY TO USE THE SOFTWARE, EVEN IF Suite Solutions, Ltd.
HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

Suite Solutions, Ltd. and its licensors shall not be liable for any
damages suffered by any person as a result of using and/or modifying the
Software or its derivatives. In no event shall Suite Solutions, Ltd.'s
liability for any damages hereunder exceed the amounts received by Suite Solutions, Ltd, Inc. 
as a result of this transaction.

These terms and conditions supersede the terms and conditions in any
licensing agreement to the extent that such terms and conditions conflict
with those set forth herein.

This file is part of the DITA Open Toolkit project.
See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:opentopic-func="http://www.idiominc.com/opentopic/exsl/function"
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    xmlns:dita2xslfo="http://dita-ot.sourceforge.net/ns/200910/dita2xslfo"
    xmlns:suitesol="http://suite-sol.com/namespaces/mapcounts"
    exclude-result-prefixes="suitesol opentopic-func dita2xslfo">
   
  <xsl:template match="suitesol:flagging-inside">
      <xsl:call-template name="parseFlagStyle">
         <xsl:with-param name="value">
            <xsl:value-of select="@style"/>
         </xsl:with-param>
      </xsl:call-template>
   </xsl:template>
   
   <xsl:template match="suitesol:changebar-start">
      
      <fo:change-bar-begin>
         <xsl:attribute name="change-bar-class">
            <xsl:text>dv</xsl:text>
            <xsl:value-of select="@id" />
         </xsl:attribute>

         <!--             
            change-bar-color 
      change-bar-offset
      change-bar-placement= start | end | left | right | inside | outside | alternate 
      change-bar-style = none | hidden | dotted | dashed | solid | double | groove | ridge | inset | outset
      change-bar-width
      -->

         <xsl:call-template name="parseChangeBarStyle">
            <xsl:with-param name="value">
               <xsl:value-of select="@changebar"/>
            </xsl:with-param>
         </xsl:call-template>

      </fo:change-bar-begin>

   </xsl:template>
   
   <xsl:template name="parseChangeBarStyle">
      <xsl:param name="value"/>

      <xsl:choose>
         <xsl:when test="$value = ''"/>
         <xsl:when test="contains($value,';')">
            <xsl:variable name="firstValue" select="substring-before($value,';')"/>
            <xsl:call-template name="outputChangeBarStyle">
               <xsl:with-param name="value">
                  <xsl:value-of select="$firstValue"/>
               </xsl:with-param>
            </xsl:call-template>


            <xsl:call-template name="parseChangeBarStyle">
               <xsl:with-param name="value" select="substring-after($value,';')"/>
            </xsl:call-template>
         </xsl:when>
         <xsl:otherwise>
            <xsl:call-template name="outputChangeBarStyle">
               <xsl:with-param name="value">
                  <xsl:value-of select="$value"/>
               </xsl:with-param>
            </xsl:call-template>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   
   <xsl:template name="outputChangeBarStyle">
      <xsl:param name="value"/>

      <xsl:choose>
         <xsl:when test="$value = ''"/>
         <xsl:when test="contains($value,':')">
            <xsl:variable name="attr" select="substring-before($value,':')"/>
            <xsl:variable name="val" select="substring-after($value,':')"/>

            <!-- 
            change-bar-color 
      change-bar-offset
      change-bar-placement= start | end | left | right | inside | outside | alternate 
      change-bar-style = none | hidden | dotted | dashed | solid | double | groove | ridge | inset | outset
      change-bar-width
      -->

            <xsl:choose>
               <xsl:when test="$attr='color'">
                  <xsl:attribute name="change-bar-color">
                     <xsl:value-of select="$val"/>
                  </xsl:attribute>
               </xsl:when>
               <xsl:when test="$attr='offset'">
                  <xsl:attribute name="change-bar-offset">
                     <xsl:value-of select="$val"/>
                  </xsl:attribute>
               </xsl:when>
               <xsl:when test="$attr='placement'">
                  <xsl:attribute name="change-bar-placement">
                     <xsl:value-of select="$val"/>
                  </xsl:attribute>
               </xsl:when>
               <xsl:when test="$attr='style'">
                  <xsl:attribute name="change-bar-style">
                     <xsl:value-of select="$val"/>
                  </xsl:attribute>
               </xsl:when>
               <xsl:when test="$attr='width'">
                  <xsl:attribute name="change-bar-width">
                     <xsl:value-of select="$val"/>
                  </xsl:attribute>
               </xsl:when>
            </xsl:choose>
         </xsl:when>
         <xsl:otherwise>
            <!-- do nothing -->
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   
   <xsl:template match="suitesol:changebar-end">      
      <fo:change-bar-end>
         <xsl:attribute name="change-bar-class">
            <xsl:text>dv</xsl:text>
            <xsl:value-of select="@id" />
         </xsl:attribute>
      </fo:change-bar-end>

   </xsl:template>
   
   <xsl:template name="parseFlagStyle">
      <xsl:param name="value"/>

      <xsl:choose>
         <xsl:when test="$value = ''"/>
         <xsl:when test="contains($value,';')">
            <xsl:variable name="firstValue" select="substring-before($value,';')"/>
            <xsl:call-template name="outputFlagStyle">
               <xsl:with-param name="value">
                  <xsl:value-of select="$firstValue"/>
               </xsl:with-param>
            </xsl:call-template>

            <xsl:call-template name="parseFlagStyle">
               <xsl:with-param name="value" select="substring-after($value,';')"/>
            </xsl:call-template>
         </xsl:when>
         <xsl:otherwise>
            <xsl:call-template name="outputFlagStyle">
               <xsl:with-param name="value">
                  <xsl:value-of select="$value"/>
               </xsl:with-param>
            </xsl:call-template>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   
   <xsl:template name="outputFlagStyle">
      <xsl:param name="value"/>

      <xsl:choose>
         <xsl:when test="$value = ''"/>
         <xsl:when test="contains($value,':')">
            <xsl:variable name="attr" select="substring-before($value,':')"/>
            <xsl:variable name="val" select="substring-after($value,':')"/>
            
            <xsl:attribute name="{$attr}">
               <xsl:value-of select="$val"/>
            </xsl:attribute>
            
         </xsl:when>
         <xsl:otherwise>
            <!-- do nothing -->
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   
   <xsl:template match="suitesol:flagging-outside">         
      <fo:block>
         <xsl:call-template name="parseFlagStyle">
            <xsl:with-param name="value">
               <xsl:value-of select="@style"/>
            </xsl:with-param>
         </xsl:call-template>
         <xsl:apply-templates />
      </fo:block>
   </xsl:template>
   
   <xsl:template match="suitesol:flagging-outside-inline" priority="10">
     <fo:inline>
         <xsl:call-template name="parseFlagStyle">
            <xsl:with-param name="value">
               <xsl:value-of select="@style"/>
            </xsl:with-param>
         </xsl:call-template>
         <xsl:apply-templates />
      </fo:inline>
   </xsl:template>
</xsl:stylesheet>

