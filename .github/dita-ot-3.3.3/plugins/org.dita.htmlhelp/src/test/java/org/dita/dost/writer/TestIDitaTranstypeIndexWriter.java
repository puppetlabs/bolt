/*
 * This file is part of the DITA Open Toolkit project.
 *
 * Copyright 2010 IBM Corporation
 *
 * See the accompanying LICENSE file for applicable license.
 */

package org.dita.dost.writer;

import org.dita.dost.TestUtils;
import org.junit.Test;

import java.io.File;

import static org.junit.Assert.assertEquals;

public class TestIDitaTranstypeIndexWriter {

    public static IDitaTranstypeIndexWriter idita1 = new CHMIndexWriter();

    @Test
    public void testiditatranstypeindexwriter() {
        System.err.println(TestUtils.testStub.getName() + File.separator + "iditatranstypewriter_index.xml");
        final String outputfilename = "resources" + File.separator + "iditatranstypewriter";
        assertEquals(TestUtils.testStub.getName() + File.separator + "iditatranstypewriter.hhk", idita1.getIndexFileName(outputfilename));
    }

}
