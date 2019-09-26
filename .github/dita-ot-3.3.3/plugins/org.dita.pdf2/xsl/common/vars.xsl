<?xml version='1.0' encoding="UTF-8"?>

<!-- 
Copyright © 2004-2005 by Idiom Technologies, Inc. All rights reserved. 
IDIOM is a registered trademark of Idiom Technologies, Inc. and WORLDSERVER
and WORLDSTART are trademarks of Idiom Technologies, Inc. All other 
trademarks are the property of their respective owners. 

IDIOM TECHNOLOGIES, INC. IS DELIVERING THE SOFTWARE "AS IS," WITH 
ABSOLUTELY NO WARRANTIES WHATSOEVER, WHETHER EXPRESS OR IMPLIED,  AND IDIOM
TECHNOLOGIES, INC. DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
PURPOSE AND WARRANTY OF NON-INFRINGEMENT. IDIOM TECHNOLOGIES, INC. SHALL NOT
BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, COVER, PUNITIVE, EXEMPLARY,
RELIANCE, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF 
ANTICIPATED PROFIT), ARISING FROM ANY CAUSE UNDER OR RELATED TO  OR ARISING 
OUT OF THE USE OF OR INABILITY TO USE THE SOFTWARE, EVEN IF IDIOM
TECHNOLOGIES, INC. HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. 

Idiom Technologies, Inc. and its licensors shall not be liable for any
damages suffered by any person as a result of using and/or modifying the
Software or its derivatives. In no event shall Idiom Technologies, Inc.'s
liability for any damages hereunder exceed the amounts received by Idiom
Technologies, Inc. as a result of this transaction.

These terms and conditions supersede the terms and conditions in any
licensing agreement to the extent that such terms and conditions conflict
with those set forth herein.

This file is part of the DITA Open Toolkit project.
See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:opentopic-vars="http://www.idiominc.com/opentopic/vars"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="opentopic-vars xs">

  <!-- Override template to get current language with fixed value -->
  <xsl:template name="getLowerCaseLang" as="xs:string">
    <xsl:value-of select="lower-case(translate($locale, '_', '-'))"/>
  </xsl:template>

  <!-- Deprecated. Use getVariable template instead. -->
  <xsl:template name="insertVariable">
    <xsl:param name="theVariableID" as="xs:string"/>
    <xsl:param name="theParameters" as="document-node()*"/>
    
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX066W'"/>
      <xsl:with-param name="msgparams">%1=insertVariable</xsl:with-param>
    </xsl:call-template>
    <xsl:call-template name="getVariable">
      <xsl:with-param name="id" select="$theVariableID"/>
      <xsl:with-param name="params" select="$theParameters/*"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Support legacy variable namespace -->
  <xsl:template match="opentopic-vars:variable" mode="processVariableBody">
    <xsl:param name="params"/>

    <xsl:for-each select="node()">
      <xsl:choose>
        <xsl:when test="self::opentopic-vars:param">
          <!--Processing parametrized variable-->
          <xsl:variable name="param-name" select="@ref-name"/>
          <!--Copying parameter child as is-->
          <xsl:copy-of select="$params/descendant-or-self::*[local-name() = $param-name]/node()"/>
        </xsl:when>
        <xsl:when test="self::opentopic-vars:variable">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="@id"/>
            <xsl:with-param name="params" select="$params"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:copy-of select="."/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
  
</xsl:stylesheet>