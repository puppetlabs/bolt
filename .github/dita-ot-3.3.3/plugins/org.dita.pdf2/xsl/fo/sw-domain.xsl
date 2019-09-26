<?xml version='1.0'?>

<!-- 
Copyright © 2004-2006 by Idiom Technologies, Inc. All rights reserved. 
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

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    version="2.0">

    <xsl:template match="*[contains(@class,' sw-d/msgph ')]">
      <fo:inline xsl:use-attribute-sets="msgph">
        <xsl:call-template name="commonattributes"/>
        <xsl:apply-templates/>
      </fo:inline>
    </xsl:template>

    <xsl:template match="*[contains(@class,' sw-d/msgblock ')]">
      <xsl:call-template name="generateAttrLabel"/>
      <fo:block xsl:use-attribute-sets="msgblock">
        <xsl:call-template name="commonattributes"/>
        <xsl:call-template name="setFrame"/>
        <xsl:call-template name="setScale"/>
        <xsl:call-template name="setExpanse"/>
        <xsl:apply-templates/>
      </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class,' sw-d/msgnum ')]">
      <xsl:apply-templates select="." mode="inlineTextOptionalKeyref">
        <xsl:with-param name="copyAttributes" as="element()"><wrapper xsl:use-attribute-sets="msgnum"/></xsl:with-param>
      </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="*[contains(@class,' sw-d/cmdname ')]">
      <xsl:apply-templates select="." mode="inlineTextOptionalKeyref">
        <xsl:with-param name="copyAttributes" as="element()"><wrapper xsl:use-attribute-sets="cmdname"/></xsl:with-param>
      </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="*[contains(@class,' sw-d/varname ')]">
      <xsl:apply-templates select="." mode="inlineTextOptionalKeyref">
        <xsl:with-param name="copyAttributes" as="element()"><wrapper xsl:use-attribute-sets="varname"/></xsl:with-param>
      </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="*[contains(@class,' sw-d/filepath ')]">
      <fo:inline xsl:use-attribute-sets="filepath">
        <xsl:call-template name="commonattributes"/>
        <xsl:apply-templates/>
      </fo:inline>
    </xsl:template>

    <xsl:template match="*[contains(@class,' sw-d/userinput ')]">
      <fo:inline xsl:use-attribute-sets="userinput">
        <xsl:call-template name="commonattributes"/>
        <xsl:apply-templates/>
      </fo:inline>
    </xsl:template>

    <xsl:template match="*[contains(@class,' sw-d/systemoutput ')]">
      <fo:inline xsl:use-attribute-sets="systemoutput">
        <xsl:call-template name="commonattributes"/>
        <xsl:apply-templates/>
      </fo:inline>
    </xsl:template>

</xsl:stylesheet>