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
    xmlns:opentopic-i18n="http://www.idiominc.com/opentopic/i18n"
    xmlns:opentopic-index="http://www.idiominc.com/opentopic/index"
    xmlns:opentopic="http://www.idiominc.com/opentopic"
    xmlns:opentopic-func="http://www.idiominc.com/opentopic/exsl/function"
    xmlns:ditaarch="http://dita.oasis-open.org/architecture/2005/"
    exclude-result-prefixes="opentopic-index opentopic opentopic-i18n opentopic-func"
    version="2.0">

    <xsl:import href="plugin:org.dita.base:xsl/common/dita-utilities.xsl"/>
    <xsl:import href="plugin:org.dita.base:xsl/common/dita-textonly.xsl"/>
    <xsl:import href="plugin:org.dita.base:xsl/common/related-links.xsl"/>
    
    <xsl:import href="plugin:org.dita.pdf2:xsl/common/attr-set-reflection.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/common/vars.xsl"/>
    
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/basic-settings.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/layout-masters-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/layout-masters.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/links-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/links.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/lists-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/lists.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/tables-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/tables.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/root-processing.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/topic-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/concept-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/commons-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/commons.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/toc-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/toc.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/bookmarks.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/index-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/index.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/front-matter-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/front-matter.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/preface.xsl"/>
    
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/map-elements-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/map-elements.xsl"/>
    
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/task-elements-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/task-elements.xsl"/>
    
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/reference-elements-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/reference-elements.xsl"/>
    
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/sw-domain-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/sw-domain.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/pr-domain-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/pr-domain.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/hi-domain-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/hi-domain.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/ui-domain-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/ui-domain.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/ut-domain.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/abbrev-domain.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/markup-domain-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/markup-domain.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/xml-domain-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/xml-domain.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/svg-domain-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/svg-domain.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/hazard-d-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/hazard-d.xsl"/>
    
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/static-content-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/static-content.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/glossary-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/glossary.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/lot-lof-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/lot-lof.xsl"/>
    
    <xsl:import href="plugin:org.dita.pdf2:cfg/fo/attrs/learning-elements-attr.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/learning-elements.xsl"/>
    
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/flagging.xsl"/>
    <xsl:import href="plugin:org.dita.pdf2:xsl/fo/flagging-from-preprocess.xsl"/>


    <xsl:output method="xml" encoding="utf-8" indent="no"/>

</xsl:stylesheet>